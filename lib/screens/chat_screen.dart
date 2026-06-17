// lib/screens/chat_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;

  const ChatScreen({
    Key? key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  String? _recordingPath;
  bool _isRecording = false;
  String? _playingMessageId;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _resetUnreadAndLastRead();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _resetUnreadAndLastRead() async {
    await _db.collection('conversations').doc(widget.conversationId).update({
      'msgUnread_$_uid': 0,
      'lastRead_$_uid': FieldValue.serverTimestamp(),
    });
  }

  // ─── Envoi ───────────────────────────────────────────────────────────────

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    await _sendMessage('text', text, text);
  }

  Future<void> _sendImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final url = await _uploadFile(File(picked.path), 'jpg');
    await _sendMessage('image', url, '📷 Photo');
  }

  Future<void> _sendVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    final url = await _uploadFile(File(picked.path), 'mp4');
    await _sendMessage('video', url, '🎥 Vidéo');
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;
    final dir = await getTemporaryDirectory();
    _recordingPath = p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.m4a');
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: _recordingPath!);
    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    await _recorder.stop();
    setState(() => _isRecording = false);
    if (_recordingPath == null) return;
    final file = File(_recordingPath!);
    if (!file.existsSync()) return;
    final url = await _uploadFile(file, 'm4a');
    await _sendMessage('voice', url, '🎤 Note vocale');
  }

  Future<String> _uploadFile(File file, String ext) async {
    final ref = _storage.ref('chat_media/$_uid/${DateTime.now().millisecondsSinceEpoch}.$ext');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<void> _sendMessage(String type, String content, String preview) async {
    final batch = _db.batch();
    final msgRef = _db
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .doc();

    batch.set(msgRef, {
      'senderId': _uid,
      'type': type,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
      'edited': false,
    });

    batch.update(
      _db.collection('conversations').doc(widget.conversationId),
      {
        'lastMessage': preview,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': _uid,
        'msgUnread_${widget.otherUserId}': FieldValue.increment(1),
      },
    );

    await batch.commit();
    _scrollToBottom();
  }

  // ─── Appui long : Modifier / Supprimer ───────────────────────────────────

  void _onLongPress(
    String msgId,
    String type,
    String content,
    DateTime? timestamp,
    DateTime? otherLastRead,
  ) {
    final now = DateTime.now();

    // Vu = l'autre utilisateur a lu après l'envoi du message
    final isSeen = otherLastRead != null &&
        timestamp != null &&
        otherLastRead.isAfter(timestamp);

    // Expiré = plus de 5 minutes depuis l'envoi
    final isExpired = timestamp != null &&
        now.difference(timestamp).inMinutes >= 5;

    final canEdit = type == 'text' && !isSeen && !isExpired;
    final canDelete = !isSeen;

    // Aucune action disponible → SnackBar
    if (!canEdit && !canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce message a déjà été vu et ne peut plus être modifié ni supprimé.'),
          backgroundColor: Color(0xFF1B3D6E),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Color(0xFF1B3D6E)),
                title: const Text('Modifier le message'),
                subtitle: Text(
                  _editTimeLeft(timestamp!),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(msgId, content);
                },
              ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFB12831)),
                title: const Text('Supprimer le message',
                    style: TextStyle(color: Color(0xFFB12831))),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(msgId);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Affiche le temps restant pour modifier (ex: "encore 3 min pour modifier")
  String _editTimeLeft(DateTime timestamp) {
    final elapsed = DateTime.now().difference(timestamp).inSeconds;
    final remaining = (5 * 60) - elapsed;
    if (remaining <= 0) return 'Délai expiré';
    final min = remaining ~/ 60;
    final sec = remaining % 60;
    if (min > 0) return 'Encore ${min}min${sec > 0 ? ' ${sec}s' : ''} pour modifier';
    return 'Encore ${sec}s pour modifier';
  }

  void _showEditDialog(String msgId, String currentContent) {
    final editController = TextEditingController(text: currentContent);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le message'),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Nouveau contenu...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B3D6E),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newText = editController.text.trim();
              if (newText.isNotEmpty && newText != currentContent) {
                await _db
                    .collection('conversations')
                    .doc(widget.conversationId)
                    .collection('messages')
                    .doc(msgId)
                    .update({
                  'content': newText,
                  'edited': true,
                });
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String msgId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le message'),
        content: const Text('Ce message sera supprimé définitivement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB12831),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteMessage(msgId);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(String msgId) async {
    final convRef = _db.collection('conversations').doc(widget.conversationId);
    final msgRef = convRef.collection('messages').doc(msgId);

    // Vérifier si c'est le dernier message → mettre à jour lastMessage de la conversation
    final convSnap = await convRef.get();
    final convData = convSnap.data() as Map<String, dynamic>? ?? {};

    // Supprimer le message
    await msgRef.delete();

    // Si c'était le dernier message, recharger le nouveau dernier
    final remaining = await convRef
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (remaining.docs.isEmpty) {
      await convRef.update({
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': _uid,
      });
    } else {
      final lastData = remaining.docs.first.data();
      final lastType = lastData['type'] as String? ?? 'text';
      String preview;
      switch (lastType) {
        case 'image': preview = '📷 Photo'; break;
        case 'video': preview = '🎥 Vidéo'; break;
        case 'voice': preview = '🎤 Note vocale'; break;
        default: preview = lastData['content'] as String? ?? '';
      }
      await convRef.update({
        'lastMessage': preview,
        'lastMessageTime': lastData['timestamp'],
        'lastSenderId': lastData['senderId'],
      });
    }
  }

  // ─── Scroll ───────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime dt) => DateFormat('HH:mm').format(dt);

  String get _otherInitials {
    final parts = widget.otherUserName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Center(
            child: Text(
              _otherInitials,
              style: TextStyle(
                fontSize: 200,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1B3D6E).withValues(alpha: 0.04),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(child: _buildMessageList()),
              _buildInputBar(),
            ],
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1B3D6E),
      foregroundColor: Colors.white,
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white24,
            child: Text(
              _otherInitials,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                StreamBuilder<DocumentSnapshot>(
                  stream: _db.collection('users').doc(widget.otherUserId).snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();
                    final data = snap.data!.data() as Map<String, dynamic>? ?? {};
                    final isOnline = data['isOnline'] as bool? ?? false;
                    final lastSeen = (data['lastSeen'] as Timestamp?)?.toDate();

                    if (isOnline) {
                      return Row(children: [
                        Container(
                          width: 7, height: 7,
                          decoration: const BoxDecoration(
                              color: Color(0xFF4CAF50), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        const Text('En ligne',
                            style: TextStyle(fontSize: 12, color: Color(0xFF4CAF50))),
                      ]);
                    } else if (lastSeen != null) {
                      final now = DateTime.now();
                      final isToday = lastSeen.day == now.day &&
                          lastSeen.month == now.month &&
                          lastSeen.year == now.year;
                      final label = isToday
                          ? 'Vu à ${_formatTime(lastSeen)}'
                          : 'Vu le ${DateFormat('dd/MM à HH:mm').format(lastSeen)}';
                      return Text(label,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7)));
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('conversations')
          .doc(widget.conversationId)
          .collection('messages')
          .orderBy('timestamp')
          .snapshots(),
      builder: (context, msgSnap) {
        if (!msgSnap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1B3D6E)));
        }
        final docs = msgSnap.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text('Aucun message\nCommencez la conversation !',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
          );
        }

        String? lastSentByMeId;
        for (final doc in docs.reversed) {
          final d = doc.data() as Map<String, dynamic>;
          if (d['senderId'] == _uid) {
            lastSentByMeId = doc.id;
            break;
          }
        }

        final lastDoc = docs.last.data() as Map<String, dynamic>;
        if (lastDoc['senderId'] == widget.otherUserId) {
          _resetUnreadAndLastRead();
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: _db.collection('conversations').doc(widget.conversationId).snapshots(),
          builder: (context, convSnap) {
            DateTime? otherLastRead;
            if (convSnap.hasData && convSnap.data!.exists) {
              final cd = convSnap.data!.data() as Map<String, dynamic>? ?? {};
              otherLastRead =
                  (cd['lastRead_${widget.otherUserId}'] as Timestamp?)?.toDate();
            }

            _scrollToBottom();

            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final isMe = data['senderId'] == _uid;
                final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                final type = data['type'] as String? ?? 'text';
                final edited = data['edited'] as bool? ?? false;

                // Regroupement timestamps
                bool showTime = true;
                if (index > 0) {
                  final prev = docs[index - 1].data() as Map<String, dynamic>;
                  final prevTime = (prev['timestamp'] as Timestamp?)?.toDate();
                  if (prevTime != null && timestamp != null) {
                    final sameMinute = prevTime.year == timestamp.year &&
                        prevTime.month == timestamp.month &&
                        prevTime.day == timestamp.day &&
                        prevTime.hour == timestamp.hour &&
                        prevTime.minute == timestamp.minute;
                    showTime = !(sameMinute && prev['senderId'] == data['senderId']);
                  }
                }

                // "Vu à HH:mm"
                final isLastSentByMe = doc.id == lastSentByMeId;
                bool showVu = false;
                if (isLastSentByMe && otherLastRead != null && timestamp != null) {
                  showVu = otherLastRead.isAfter(timestamp);
                }

                return Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // Appui long uniquement sur ses propres messages
                    GestureDetector(
                      onLongPress: isMe
                          ? () => _onLongPress(
                                doc.id,
                                type,
                                data['content'] ?? '',
                                timestamp,
                                otherLastRead,
                              )
                          : null,
                      child: _buildBubble(data, isMe, doc.id, edited),
                    ),
                    if (showTime && timestamp != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 2),
                        child: Text(_formatTime(timestamp),
                            style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ),
                    if (showVu)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.done_all,
                                size: 14, color: Color(0xFF5BC0DE)),
                            const SizedBox(width: 3),
                            Text('Vu à ${_formatTime(otherLastRead!)}',
                                style: const TextStyle(
                                    fontSize: 10, color: Color(0xFF5BC0DE))),
                          ],
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBubble(
      Map<String, dynamic> data, bool isMe, String msgId, bool edited) {
    final type = data['type'] as String? ?? 'text';
    final content = data['content'] as String? ?? '';

    Widget body;
    bool hasPadding = true;

    switch (type) {
      case 'image':
        hasPadding = false;
        body = ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: CachedNetworkImage(
            imageUrl: content,
            width: 220,
            fit: BoxFit.cover,
            placeholder: (_, __) => const SizedBox(
              width: 220,
              height: 140,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        );
        break;
      case 'video':
        hasPadding = false;
        body = ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 220,
            height: 140,
            color: Colors.black54,
            child: const Icon(Icons.play_circle_fill,
                color: Colors.white, size: 50),
          ),
        );
        break;
      case 'voice':
        body = _buildVoiceBubble(content, msgId, isMe);
        break;
      default:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              content,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            if (edited)
              Text(
                '(modifié)',
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.black38,
                ),
              ),
          ],
        );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: hasPadding
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
          : EdgeInsets.zero,
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF1B3D6E) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMe ? 18 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: body,
    );
  }

  Widget _buildVoiceBubble(String url, String msgId, bool isMe) {
    final isPlaying = _playingMessageId == msgId;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () async {
            if (isPlaying) {
              await _player.stop();
              setState(() => _playingMessageId = null);
            } else {
              setState(() => _playingMessageId = msgId);
              await _player.play(UrlSource(url));
              _player.onPlayerComplete.listen((_) {
                if (mounted) setState(() => _playingMessageId = null);
              });
            }
          },
          child: Icon(
            isPlaying ? Icons.stop_circle : Icons.play_circle_fill,
            color: isMe ? Colors.white : const Color(0xFF1B3D6E),
            size: 30,
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.graphic_eq,
            color: isMe ? Colors.white70 : Colors.grey, size: 20),
        const SizedBox(width: 4),
        Text('Note vocale',
            style: TextStyle(
                color: isMe ? Colors.white : Colors.black87, fontSize: 13)),
      ],
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file, color: Color(0xFF1B3D6E)),
              onPressed: _showAttachMenu,
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: InputDecoration(
                  hintText: 'Message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF0F0F0),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onLongPress: _startRecording,
              onLongPressEnd: (_) => _stopRecording(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isRecording
                      ? const Color(0xFFB12831)
                      : const Color(0xFF1B3D6E),
                  shape: BoxShape.circle,
                ),
                child: Icon(_isRecording ? Icons.stop : Icons.mic,
                    color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _sendText,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                    color: Color(0xFF1B3D6E), shape: BoxShape.circle),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _attachOption(Icons.image_outlined, 'Image', () {
              Navigator.pop(context);
              _sendImage();
            }),
            _attachOption(Icons.videocam_outlined, 'Vidéo', () {
              Navigator.pop(context);
              _sendVideo();
            }),
          ],
        ),
      ),
    );
  }

  Widget _attachOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
                color: Color(0xFF1B3D6E), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

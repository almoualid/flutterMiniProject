// lib/features/ai_assistant/screens/ai_assistant_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:student_companion/features/ai_assistant/data/models/chat_message.dart';
import 'package:student_companion/features/ai_assistant/data/models/chat_session.dart';
import 'package:student_companion/features/ai_assistant/data/services/chat_storage_service.dart';
import 'package:student_companion/features/ai_assistant/data/services/file_bytes_reader.dart';
import 'package:student_companion/features/ai_assistant/data/services/gemini_service.dart';
import 'package:student_companion/features/ai_assistant/data/services/pdf_text_extractor_service.dart';

const _primaryColor = Color(0xFF2952CC);
const _primaryDarkColor = Color(0xFF173B9C);
const _secondaryColor = Color(0xFF7C5CFF);
const _accentColor = Color(0xFF16B8D9);
const _surfaceColor = Color(0xFFFFFFFF);
const _backgroundColor = Color(0xFFF6F8FC);
const _textColor = Color(0xFF172033);
const _mutedTextColor = Color(0xFF64708A);
const _borderColor = Color(0xFFE1E7F2);

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<ChatSession> _savedSessions = [];
  String? _currentSessionId;
  bool _isLoading = false;
  bool _isProcessingAttachment = false;

  // File attachment state
  String? _attachedFileName;
  String? _attachedFileContent;
  String? _attachedFileExtension;
  Uint8List? _attachedPdfBytes;

  bool get _canSend =>
      !_isLoading &&
      !_isProcessingAttachment &&
      (_controller.text.trim().isNotEmpty ||
          _attachedFileContent != null ||
          _attachedPdfBytes != null);

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    unawaited(_loadSavedSessions());
  }

  Future<void> _loadSavedSessions() async {
    final sessions = await ChatStorageService.loadAllSessions();
    if (!mounted) return;
    setState(() => _savedSessions = sessions);
  }

  Future<void> _sendMessage(String text) async {
    final typedText = text.trim();
    final hasPdf =
        _attachedPdfBytes != null && _attachedFileExtension == 'pdf';
    final hasFile = _attachedFileContent != null || hasPdf;

    // Need at least a typed message OR an attached file.
    if (typedText.isEmpty && !hasFile) return;
    if (_isLoading) return;
    if (_isProcessingAttachment) return;

    String displayText;
    if (hasFile && typedText.isNotEmpty) {
      displayText = '📎 $_attachedFileName\n$typedText';
    } else if (hasFile) {
      displayText =
          '📎 $_attachedFileName\nRésume ce cours et identifie les points clés.';
    } else {
      displayText = typedText;
    }

    // Text files keep using the normal chat path; PDFs are sent as bytes below.
    String apiText;
    if (hasPdf) {
      apiText = typedText.isNotEmpty
          ? typedText
          : 'Resume ce cours et identifie les points cles importants.';
    } else if (hasFile) {
      final userInstruction = typedText.isNotEmpty
          ? typedText
          : 'Résume ce cours et identifie les points clés importants.';
      apiText = _buildFileApiText(
        userInstruction: userInstruction,
        fileName: _attachedFileName ?? 'cours',
        fileContent: _attachedFileContent!,
      );
    } else {
      apiText = typedText;
    }

    final userMessage = hasFile
        ? ChatMessage.fromUserWithFile(
            displayText: displayText,
            apiText: apiText,
          )
        : ChatMessage.fromUser(typedText);

    final pdfBytes = _attachedPdfBytes;

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _attachedFileName = null;
      _attachedFileContent = null;
      _attachedFileExtension = null;
      _attachedPdfBytes = null;
    });

    _controller.clear();
    _inputFocusNode.unfocus();
    _scrollToBottom();

    final response = hasPdf && pdfBytes != null
        ? await GeminiService.summarizePdf(pdfBytes)
        : await GeminiService.sendMessage(_messages);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _messages.add(ChatMessage.fromModel(response));
    });

    _scrollToBottom();
  }

  Future<void> _saveCurrentSession() async {
    final messagesToSave = _messages
        .where((message) => !message.isLoading)
        .toList(growable: false);
    if (messagesToSave.isEmpty) return;

    ChatSession? existingSession;
    for (final session in _savedSessions) {
      if (session.id == _currentSessionId) {
        existingSession = session;
        break;
      }
    }
    final now = DateTime.now();
    final session = ChatSession(
      id: existingSession?.id ?? now.microsecondsSinceEpoch.toString(),
      title: _buildSessionTitle(messagesToSave),
      messages: messagesToSave,
      createdAt: existingSession?.createdAt ?? now,
    );

    await ChatStorageService.saveSession(session);
    _currentSessionId = session.id;
    await _loadSavedSessions();
  }

  String _buildSessionTitle(List<ChatMessage> messages) {
    String? firstUserMessage;
    for (final message in messages) {
      if (message.role == MessageRole.user) {
        firstUserMessage = message.content;
        break;
      }
    }
    final source = (firstUserMessage ?? messages.first.content)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (source.isEmpty) return 'Nouvelle discussion';
    return source.length <= 30 ? source : '${source.substring(0, 30)}...';
  }

  Future<void> _startNewChat() async {
    if (_isLoading || _isProcessingAttachment) return;

    await _saveCurrentSession();
    if (!mounted) return;

    setState(() {
      _messages.clear();
      _currentSessionId = null;
      _attachedFileName = null;
      _attachedFileContent = null;
      _attachedFileExtension = null;
      _attachedPdfBytes = null;
    });
  }

  Future<void> _loadSession(ChatSession session) async {
    if (_isLoading || _isProcessingAttachment) return;

    await _saveCurrentSession();
    if (!mounted) return;

    setState(() {
      _messages
        ..clear()
        ..addAll(session.messages);
      _currentSessionId = session.id;
      _attachedFileName = null;
      _attachedFileContent = null;
      _attachedFileExtension = null;
      _attachedPdfBytes = null;
    });
    _scrollToBottom();
  }

  Future<void> _deleteSession(String id) async {
    await ChatStorageService.deleteSession(id);
    if (!mounted) return;

    setState(() {
      _savedSessions.removeWhere((session) => session.id == id);
      if (_currentSessionId == id) {
        _currentSessionId = null;
        _messages.clear();
      }
    });
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'pdf', 'md'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final extension = _fileExtension(file.name, file.extension);
      final bytes = file.bytes;
      String? content;
      Uint8List? pdfBytes;

      if (!_isSupportedFileExtension(extension)) {
        _showErrorSnackBar(
          'Format non supporte. Choisissez un fichier PDF, TXT ou MD.',
        );
        return;
      }

      if (extension != 'pdf' && (bytes == null || bytes.isEmpty)) {
        _showErrorSnackBar('Impossible de lire le fichier selectionne.');
        return;
      }

      setState(() => _isProcessingAttachment = true);

      if (extension == 'pdf') {
        // Flutter Web does not expose file paths. Use in-memory bytes there,
        // and only read File(path) on IO platforms where paths are available.
        if (kIsWeb) {
          pdfBytes = file.bytes;
        } else {
          final path = file.path;
          if (path == null || path.isEmpty) {
            _showErrorSnackBar(
              'Impossible de lire le fichier PDF selectionne.',
            );
            return;
          }
          pdfBytes = await readFileBytesFromPath(path);
        }

        if (pdfBytes == null || pdfBytes.isEmpty) {
          _showErrorSnackBar('Impossible de lire le fichier PDF selectionne.');
          return;
        }
      } else {
        content = PdfTextExtractorService.cleanExtractedText(
          utf8.decode(bytes!, allowMalformed: true),
        );
      }

      if (extension != 'pdf' && (content == null || content.isEmpty)) {
        throw const PdfTextExtractionException(
          'Impossible d\'extraire du texte lisible de ce fichier.',
        );
      }

      // Truncate text files if too long (Gemini token limits).
      if (extension != 'pdf' && content != null && content.length > 8000) {
        content =
            '${content.substring(0, 8000)}\n... [fichier tronqué à 8000 caractères]';
      }

      setState(() {
        _attachedFileName = file.name;
        _attachedFileContent = content;
        _attachedFileExtension = extension;
        _attachedPdfBytes = pdfBytes;
        if (_controller.text.isEmpty) {
          _controller.text = extension == 'pdf'
              ? 'Resume le cours suivant en francais simple.'
              : 'Résume ce cours et identifie les points clés.';
        }
      });
      _inputFocusNode.requestFocus();
    } on PdfTextExtractionException catch (e) {
      _showErrorSnackBar(e.message);
    } catch (e) {
      _showErrorSnackBar('Erreur lors du chargement : $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessingAttachment = false);
      }
    }
  }

  String _buildFileApiText({
    required String userInstruction,
    required String fileName,
    required String fileContent,
  }) {
    return '$userInstruction\n\n--- Contenu du fichier "$fileName" ---\n$fileContent';
  }

  String _fileExtension(String fileName, String? pickerExtension) {
    final extension = pickerExtension?.trim().toLowerCase();
    if (extension != null && extension.isNotEmpty) return extension;

    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) return '';
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  bool _isSupportedFileExtension(String extension) {
    return extension == 'pdf' || extension == 'txt' || extension == 'md';
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _removeAttachment() {
    setState(() {
      _attachedFileName = null;
      _attachedFileContent = null;
      _attachedFileExtension = null;
      _attachedPdfBytes = null;
    });
  }

  void _useSuggestion(String suggestion) {
    _controller.text = suggestion;
    _controller.selection = TextSelection.collapsed(offset: suggestion.length);
    _inputFocusNode.requestFocus();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: Navigator.of(context).canPop()
            ? IconButton(
                tooltip: 'Retour',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        title: const Text('StudyBot'),
        actions: [
          IconButton(
            tooltip: 'Enregistrer',
            onPressed: _messages.isEmpty
                ? null
                : () => unawaited(_saveCurrentSession()),
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: 'Nouvelle conversation',
            onPressed: _isLoading || _isProcessingAttachment
                ? null
                : () => unawaited(_startNewChat()),
            icon: const Icon(Icons.add_comment_outlined),
          ),
          IconButton(
            tooltip: 'Historique',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      drawer: ChatHistoryDrawer(
        sessions: _savedSessions,
        currentSessionId: _currentSessionId,
        onLoadSession: _loadSession,
        onDeleteSession: _deleteSession,
      ),
      backgroundColor: _backgroundColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 900 ? 24.0 : 0.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    children: [
                      // Assistant header
                      AssistantHeader(
                        hasMessages: _messages.isNotEmpty,
                        isLoading: _isLoading || _isProcessingAttachment,
                        onClearChat: () => unawaited(_startNewChat()),
                      ),
                      Expanded(
                        // Message list
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _messages.isEmpty
                              ? EmptyAssistantState(
                                  key: const ValueKey('empty-state'),
                                  onSuggestionSelected: _useSuggestion,
                                )
                              : _MessageList(
                                  key: const ValueKey('message-list'),
                                  messages: _messages,
                                  isLoading: _isLoading,
                                  scrollController: _scrollController,
                                ),
                        ),
                      ),
                      // Input area
                      ChatInputBar(
                        controller: _controller,
                        focusNode: _inputFocusNode,
                        attachedFileName: _attachedFileName,
                        isLoading: _isLoading,
                        isProcessingAttachment: _isProcessingAttachment,
                        canSend: _canSend,
                        onPickFile: _pickFile,
                        onRemoveAttachment: _removeAttachment,
                        onSend: () => _sendMessage(_controller.text),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_saveCurrentSession());
    _controller.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }
}

class ChatHistoryDrawer extends StatelessWidget {
  const ChatHistoryDrawer({
    super.key,
    required this.sessions,
    required this.currentSessionId,
    required this.onLoadSession,
    required this.onDeleteSession,
  });

  final List<ChatSession> sessions;
  final String? currentSessionId;
  final ValueChanged<ChatSession> onLoadSession;
  final ValueChanged<String> onDeleteSession;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Text(
                'Historique',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _textColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Aucune conversation sauvegardee.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: _mutedTextColor),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: sessions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 2),
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final selected = session.id == currentSessionId;

                        return Dismissible(
                          key: ValueKey(session.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red.shade700,
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (_) => onDeleteSession(session.id),
                          child: ListTile(
                            selected: selected,
                            selectedTileColor: const Color(0xFFEAF8FC),
                            leading: Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: selected ? _primaryColor : _mutedTextColor,
                            ),
                            title: Text(
                              session.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              _formatSessionDate(session.createdAt),
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              onLoadSession(session);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSessionDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }
}

class AssistantHeader extends StatelessWidget {
  const AssistantHeader({
    super.key,
    required this.hasMessages,
    required this.isLoading,
    required this.onClearChat,
  });

  final bool hasMessages;
  final bool isLoading;
  final VoidCallback onClearChat;

@override
Widget build(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final isCompact = width < 520;

  bool showWidget = false;

  return Visibility(
    visible: showWidget,
    child: Container(
      margin: EdgeInsets.fromLTRB(
        isCompact ? 12 : 16,
        12,
        isCompact ? 12 : 16,
        8,
      ),
      padding: EdgeInsets.all(isCompact ? 16 : 20),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: isCompact ? 48 : 56,
            height: isCompact ? 48 : 56,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryColor, _secondaryColor],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    this.soft = false,
  });

  final IconData icon;
  final String label;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: soft ? const Color(0xFFF1EEFF) : const Color(0xFFEAF8FC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: soft ? _secondaryColor : _accentColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: soft ? _secondaryColor : const Color(0xFF087A91),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyAssistantState extends StatelessWidget {
  const EmptyAssistantState({super.key, required this.onSuggestionSelected});

  final ValueChanged<String> onSuggestionSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primaryDarkColor, _primaryColor, _secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x262952CC),
                      blurRadius: 28,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: const Color(0x33FFFFFF),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0x55FFFFFF)),
                      ),
                      child: const Icon(
                        Icons.psychology_alt_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Bonjour, je suis votre assistant académique',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Demandez un résumé, une explication ou un plan de révision adapté à votre rythme.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xDFFFFFFF),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Suggestions rapides',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Suggestion chips
              SuggestionChipList(onSelected: onSuggestionSelected),
            ],
          ),
        ),
      ),
    );
  }
}

class SuggestionChipList extends StatelessWidget {
  const SuggestionChipList({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  static const _suggestions = [
    _Suggestion(Icons.summarize_rounded, 'Résume ce cours'),
    _Suggestion(Icons.event_note_rounded, 'Organise mon planning'),
    _Suggestion(Icons.assignment_rounded, 'Explique ce devoir'),
    _Suggestion(Icons.lightbulb_rounded, 'Donne-moi des conseils de révision'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final suggestion in _suggestions)
          ActionChip(
            avatar: Icon(suggestion.icon, color: _primaryColor, size: 18),
            label: Text(suggestion.label),
            labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: _textColor,
              fontWeight: FontWeight.w700,
            ),
            backgroundColor: _surfaceColor,
            side: const BorderSide(color: _borderColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            onPressed: () => onSelected(suggestion.label),
          ),
      ],
    );
  }
}

class _Suggestion {
  const _Suggestion(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    super.key,
    required this.messages,
    required this.isLoading,
    required this.scrollController,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: messages.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (isLoading && index == messages.length) {
          return const TypingIndicatorBubble();
        }
        return ChatBubble(message: messages[index]);
      },
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final maxBubbleWidth = math.min(
      MediaQuery.sizeOf(context).width * 0.78,
      660.0,
    );
    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(22),
      topRight: const Radius.circular(22),
      bottomLeft: Radius.circular(isUser ? 22 : 6),
      bottomRight: Radius.circular(isUser ? 6 : 22),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) const _AssistantAvatar(),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: isUser
                      ? const LinearGradient(
                          colors: [_primaryColor, _secondaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isUser ? null : _surfaceColor,
                  borderRadius: bubbleRadius,
                  border: isUser ? null : Border.all(color: _borderColor),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x100B1B3D),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: SelectableText(
                    message.content,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isUser ? Colors.white : _textColor,
                      height: 1.5,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser) const _UserAvatar(),
        ],
      ),
    );
  }
}

class TypingIndicatorBubble extends StatelessWidget {
  const TypingIndicatorBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [_AssistantAvatar(), SizedBox(width: 8), _TypingCard()],
      ),
    );
  }
}

class _TypingCard extends StatefulWidget {
  const _TypingCard();

  @override
  State<_TypingCard> createState() => _TypingCardState();
}

class _TypingCardState extends State<_TypingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
          bottomLeft: Radius.circular(6),
          bottomRight: Radius.circular(22),
        ),
        border: Border.all(color: _borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100B1B3D),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'StudyBot écrit',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: _mutedTextColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  children: List.generate(3, (index) {
                    final phase = (_controller.value + index * 0.18) % 1.0;
                    final y = math.sin(phase * math.pi * 2) * 3;
                    final opacity =
                        0.45 + (math.sin(phase * math.pi * 2) + 1) * 0.25;

                    return Transform.translate(
                      offset: Offset(0, -y),
                      child: Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        decoration: BoxDecoration(
                          color: _primaryColor.withAlpha(
                            (opacity * 255).round(),
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ChatInputBar extends StatelessWidget {
  const ChatInputBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.attachedFileName,
    required this.isLoading,
    required this.isProcessingAttachment,
    required this.canSend,
    required this.onPickFile,
    required this.onRemoveAttachment,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? attachedFileName;
  final bool isLoading;
  final bool isProcessingAttachment;
  final bool canSend;
  final VoidCallback onPickFile;
  final VoidCallback onRemoveAttachment;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, math.max(bottomInset, 10)),
      decoration: const BoxDecoration(
        color: _surfaceColor,
        border: Border(top: BorderSide(color: _borderColor)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F0B1B3D),
            blurRadius: 18,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isProcessingAttachment) ...[
                const _AttachmentLoadingState(),
                const SizedBox(height: 8),
              ],
              if (attachedFileName != null) ...[
                _AttachmentPreview(
                  fileName: attachedFileName!,
                  onRemove: onRemoveAttachment,
                ),
                const SizedBox(height: 8),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _backgroundColor,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 4),
                            child: IconButton(
                              tooltip: 'Uploader un cours (.txt, .pdf, .md)',
                              onPressed: isLoading || isProcessingAttachment
                                  ? null
                                  : onPickFile,
                              icon: isProcessingAttachment
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                      ),
                                    )
                                  : Icon(
                                      attachedFileName == null
                                          ? Icons.attach_file_rounded
                                          : Icons.check_circle_rounded,
                                    ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: controller,
                              focusNode: focusNode,
                              minLines: 1,
                              maxLines: 5,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) {
                                if (canSend) onSend();
                              },
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: _textColor, height: 1.35),
                              decoration: InputDecoration(
                                hintText: 'Posez votre question à StudyBot...',
                                hintStyle: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(color: _mutedTextColor),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Tooltip(
                    message: canSend ? 'Envoyer' : 'Ajoutez une question',
                    child: FilledButton(
                      onPressed: canSend ? onSend : null,
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(16),
                        backgroundColor: _primaryColor,
                        disabledBackgroundColor: const Color(0xFFD8DEEA),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 22),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentLoadingState extends StatelessWidget {
  const _AttachmentLoadingState();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC8EEF6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Extraction du texte du PDF...',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF087A91),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({required this.fileName, required this.onRemove});

  final String fileName;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1EEFF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFDCD4FF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.insert_drive_file_rounded,
              size: 18,
              color: _secondaryColor,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: _primaryDarkColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Retirer le fichier',
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor, _secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: 18,
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8FC),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFC8EEF6)),
      ),
      child: const Icon(
        Icons.person_rounded,
        color: Color(0xFF087A91),
        size: 18,
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../services/api_client.dart';

Map<String, String> get _authHeaders => {
  'Content-Type': 'application/json',
  'Authorization': 'Bearer ${ApiClient.instance.token}',
};

enum TicketStatus { exitoso, rechazado, pendiente, enProceso }

enum MessageType { incoming, outgoing, system }

class ChatMessage {
  final String id;
  final String text;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.type,
    required this.timestamp,
    this.isRead = true,
  });
}

class Ticket {
  final String id;
  final String title;
  final TicketStatus status;
  final String resolution;
  final DateTime date;

  const Ticket({
    required this.id,
    required this.title,
    required this.status,
    required this.resolution,
    required this.date,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      status: _parseStatus(json['status']?.toString()),
      resolution: json['resolution']?.toString() ?? '',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static TicketStatus _parseStatus(String? s) {
    switch (s) {
      case 'exitoso':
        return TicketStatus.exitoso;
      case 'rechazado':
        return TicketStatus.rechazado;
      case 'pendiente':
        return TicketStatus.pendiente;
      case 'enProceso':
        return TicketStatus.enProceso;
      default:
        return TicketStatus.pendiente;
    }
  }
}

final List<ChatMessage> _mockMessages = [
  ChatMessage(
    id: '1',
    text: '¿Los datos de los reportes de la semana pasada tienen los costos correctos?',
    type: MessageType.incoming,
    timestamp: DateTime.now().subtract(const Duration(minutes: 18)),
  ),
  ChatMessage(
    id: '2',
    text: 'Revisando ahora mismo, dame un momento.',
    type: MessageType.outgoing,
    timestamp: DateTime.now().subtract(const Duration(minutes: 16)),
    isRead: true,
  ),
];

final List<Ticket> _mockTickets = [
  Ticket(
    id: 'T-001',
    title: 'Ticket Core 1',
    status: TicketStatus.exitoso,
    resolution: 'Soporte y Reportes',
    date: DateTime(2023, 11, 23),
  ),
  Ticket(
    id: 'T-002',
    title: 'Ticket Core 2',
    status: TicketStatus.rechazado,
    resolution: 'Retorte',
    date: DateTime(2024, 11, 21),
  ),
  Ticket(
    id: 'T-003',
    title: 'Ticket Core 3',
    status: TicketStatus.enProceso,
    resolution: 'En revisión',
    date: DateTime(2024, 12, 1),
  ),
];

class SupportReportsScreen extends StatefulWidget {
  const SupportReportsScreen({super.key});

  @override
  State<SupportReportsScreen> createState() => _SupportReportsScreenState();
}

class _SupportReportsScreenState extends State<SupportReportsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  late List<ChatMessage> _chatMessages;
  late List<Ticket> _tickets;
  bool _isSending = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _chatMessages = List.from(_mockMessages);
    _tickets = List.from(_mockTickets);
    _tabController = TabController(length: 2, vsync: this);
    _fetchTickets();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchTickets() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiClient.baseUrl}/api/admin/reports'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        setState(() {
          _tickets = data.map((e) => Ticket.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Error al obtener tickets');
      }
    } catch (_) {
      setState(() {
        _tickets = List.from(_mockTickets);
        _isLoading = false;
      });
    }
  }

  Future<void> _resolveTicket(String id) async {
    try {
      final res = await http.put(
        Uri.parse('${ApiClient.baseUrl}/api/admin/reports/$id/resolve'),
        headers: _authHeaders,
      );
      if (res.statusCode == 200) {
        _fetchTickets();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al resolver el ticket, usa el fallback')),
        );
      }
    }
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    setState(() {
      _isSending = true;
      _chatMessages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        type: MessageType.outgoing,
        timestamp: DateTime.now(),
      ));
      _inputController.clear();
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() => _isSending = false);
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildChatTab(),
                  _buildTicketsTab(),
                ],
              ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: Color(0xFF1A1A2E)),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.headset_mic_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SOPORTE Y REPORTES',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  'GET /api/admin/reports',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    fontFamily: 'Courier',
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'En línea',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.more_horiz_rounded,
                color: Colors.grey.shade600, size: 22),
            onPressed: () => _showMoreOptions(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF667EEA),
        unselectedLabelColor: Colors.grey.shade500,
        indicatorColor: const Color(0xFF667EEA),
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        tabs: [
          const Tab(text: 'Conversación'),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Tickets'),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667EEA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_tickets.length}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _chatMessages.length,
      itemBuilder: (context, index) {
        final msg = _chatMessages[index];
        final showDate = index == 0 ||
            _chatMessages[index - 1].timestamp.day != msg.timestamp.day;

        return Column(
          children: [
            if (showDate) _buildDateDivider(msg.timestamp),
            _ChatBubble(message: msg),
          ],
        );
      },
    );
  }

  Widget _buildDateDivider(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300, thickness: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatDate(date),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300, thickness: 0.5)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day) return 'Hoy';
    if (date.day == now.day - 1) return 'Ayer';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildTicketsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _fetchTickets,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tickets.length,
        itemBuilder: (context, index) => _TicketCard(
          ticket: _tickets[index],
          onResolve: _resolveTicket,
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.attach_file_rounded,
                size: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _inputController,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Escribe una resolución...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667EEA).withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _sendMessage,
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            _SheetOption(icon: Icons.info_outline_rounded, label: 'Ver detalles del caso'),
            _SheetOption(icon: Icons.download_outlined, label: 'Exportar conversación'),
            _SheetOption(icon: Icons.archive_outlined, label: 'Archivar ticket'),
            _SheetOption(
              icon: Icons.flag_outlined,
              label: 'Marcar como urgente',
              color: Colors.orange,
            ),
            _SheetOption(
              icon: Icons.close_rounded,
              label: 'Cerrar caso',
              color: Colors.red,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  bool get isOutgoing => message.type == MessageType.outgoing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isOutgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOutgoing) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFEDE7F6),
              child: const Icon(
                Icons.support_agent_rounded,
                size: 16,
                color: Color(0xFF7E57C2),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isOutgoing
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isOutgoing
                        ? const LinearGradient(
                            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isOutgoing ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isOutgoing ? 16 : 4),
                      bottomRight: Radius.circular(isOutgoing ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: isOutgoing ? Colors.white : const Color(0xFF1A1A2E),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    if (isOutgoing) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.isRead
                            ? Icons.done_all_rounded
                            : Icons.done_rounded,
                        size: 12,
                        color: message.isRead
                            ? const Color(0xFF667EEA)
                            : Colors.grey.shade400,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isOutgoing) const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _TicketCard extends StatelessWidget {
  final Ticket ticket;
  final Future<void> Function(String id) onResolve;
  const _TicketCard({required this.ticket, required this.onResolve});

  Color get _statusColor {
    switch (ticket.status) {
      case TicketStatus.exitoso:
        return const Color(0xFF2E7D32);
      case TicketStatus.rechazado:
        return const Color(0xFFC62828);
      case TicketStatus.pendiente:
        return const Color(0xFFE65100);
      case TicketStatus.enProceso:
        return const Color(0xFF1565C0);
    }
  }

  Color get _statusBg {
    switch (ticket.status) {
      case TicketStatus.exitoso:
        return const Color(0xFFE8F5E9);
      case TicketStatus.rechazado:
        return const Color(0xFFFFEBEE);
      case TicketStatus.pendiente:
        return const Color(0xFFFFF3E0);
      case TicketStatus.enProceso:
        return const Color(0xFFE3F2FD);
    }
  }

  IconData get _statusIcon {
    switch (ticket.status) {
      case TicketStatus.exitoso:
        return Icons.check_circle_rounded;
      case TicketStatus.rechazado:
        return Icons.cancel_rounded;
      case TicketStatus.pendiente:
        return Icons.schedule_rounded;
      case TicketStatus.enProceso:
        return Icons.autorenew_rounded;
    }
  }

  String get _statusLabel {
    switch (ticket.status) {
      case TicketStatus.exitoso:
        return 'Exitoso';
      case TicketStatus.rechazado:
        return 'Rechazado';
      case TicketStatus.pendiente:
        return 'Pendiente';
      case TicketStatus.enProceso:
        return 'En proceso';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_statusColor, _statusColor.withValues(alpha: 0.4)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ticket.id,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                            fontFamily: 'Courier',
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _statusBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_statusIcon,
                                size: 12, color: _statusColor),
                            const SizedBox(width: 4),
                            Text(
                              _statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ticket.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _DetailRow(
                    icon: Icons.label_outline_rounded,
                    label: 'Status',
                    value: 'Soporte y Reportes',
                  ),
                  const SizedBox(height: 5),
                  _DetailRow(
                    icon: Icons.handshake_outlined,
                    label: 'Resolución',
                    value: ticket.resolution,
                  ),
                  const SizedBox(height: 5),
                  _DetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Fecha',
                    value:
                        '${ticket.date.day.toString().padLeft(2, '0')}/${ticket.date.month.toString().padLeft(2, '0')}/${ticket.date.year}',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.visibility_outlined, size: 14),
                          label: const Text('Ver'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF667EEA),
                            side: const BorderSide(
                                color: Color(0xFF667EEA), width: 1),
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed:
                              ticket.status == TicketStatus.exitoso ? null : () => onResolve(ticket.id),
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                          label: const Text('Resolver'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF667EEA),
                            disabledBackgroundColor: Colors.grey.shade300,
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1A1A2E),
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _SheetOption(
      {required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF1A1A2E);
    return ListTile(
      leading: Icon(icon, color: c, size: 20),
      title: Text(label,
          style: TextStyle(
              fontSize: 14, color: c, fontWeight: FontWeight.w500)),
      onTap: () => Navigator.pop(context),
      dense: true,
    );
  }
}

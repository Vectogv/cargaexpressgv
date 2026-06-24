import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

void main() {
  runApp(const VerificacionesApp());
}

class VerificacionesApp extends StatelessWidget {
  const VerificacionesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Verificaciones',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A1A2E),
          brightness: Brightness.light,
        ),
      ),
      home: const VerificacionesScreen(),
    );
  }
}

// ─── Modelos ───────────────────────────────────────────────────────────────────

enum DocumentStatus { pendiente, verificado, rechazado, enRevision }

class DocumentPage {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const DocumentPage({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });
}

class VerificationDocument {
  final String id;
  final String name;
  final String type;
  final DocumentStatus status;
  final DateTime uploadedAt;
  final List<DocumentPage> pages;
  final int totalPages;

  const VerificationDocument({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.uploadedAt,
    required this.pages,
    required this.totalPages,
  });
}

// ─── Datos de ejemplo ──────────────────────────────────────────────────────────

final List<VerificationDocument> _documents = [
  VerificationDocument(
    id: 'DOC-001',
    name: 'Contrato de Servicios',
    type: 'PDF • 2.4 MB',
    status: DocumentStatus.enRevision,
    uploadedAt: DateTime.now().subtract(const Duration(hours: 2)),
    totalPages: 4,
    pages: [
      DocumentPage(
        id: 'p1',
        title: 'Contrato Principal',
        subtitle: 'Términos y condiciones generales del servicio',
        icon: Icons.description_outlined,
        accentColor: const Color(0xFF1565C0),
      ),
      DocumentPage(
        id: 'p2',
        title: 'Anexo A — Tarifas',
        subtitle: 'Tabla de precios y cronograma de pagos',
        icon: Icons.table_chart_outlined,
        accentColor: const Color(0xFF2E7D32),
      ),
      DocumentPage(
        id: 'p3',
        title: 'Firmas y Sellos',
        subtitle: 'Sección de validación y rúbricas',
        icon: Icons.draw_outlined,
        accentColor: const Color(0xFF6A1B9A),
      ),
      DocumentPage(
        id: 'p4',
        title: 'Apéndice Legal',
        subtitle: 'Marco normativo aplicable',
        icon: Icons.gavel_outlined,
        accentColor: const Color(0xFF880E4F),
      ),
    ],
  ),
  VerificationDocument(
    id: 'DOC-002',
    name: 'Identificación Oficial',
    type: 'JPG • 890 KB',
    status: DocumentStatus.pendiente,
    uploadedAt: DateTime.now().subtract(const Duration(hours: 5)),
    totalPages: 2,
    pages: [
      DocumentPage(
        id: 'p1',
        title: 'Anverso — Frente',
        subtitle: 'Datos personales y fotografía',
        icon: Icons.badge_outlined,
        accentColor: const Color(0xFFE65100),
      ),
      DocumentPage(
        id: 'p2',
        title: 'Reverso — Dorso',
        subtitle: 'Código de barras y datos adicionales',
        icon: Icons.qr_code_2_rounded,
        accentColor: const Color(0xFF37474F),
      ),
    ],
  ),
];

// ─── Pantalla principal ────────────────────────────────────────────────────────

class VerificacionesScreen extends StatefulWidget {
  const VerificacionesScreen({super.key});

  @override
  State<VerificacionesScreen> createState() => _VerificacionesScreenState();
}

class _VerificacionesScreenState extends State<VerificacionesScreen>
    with TickerProviderStateMixin {
  int _selectedDoc = 0;
  int _selectedPage = 0;
  int _selectedNav = 0;
  late PageController _pageController;
  late AnimationController _approveController;
  late AnimationController _floatController;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
    _approveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -4, end: 4).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _approveController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  VerificationDocument get _currentDoc => _documents[_selectedDoc];

  void _onVerificar() {
    HapticFeedback.heavyImpact();
    _approveController.forward().then((_) {
      _approveController.reverse();
      _showConfirmDialog();
    });
  }

  void _showConfirmDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _ConfirmDialog(
        docName: _currentDoc.name,
        onConfirm: () {
          Navigator.pop(context);
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('Documento verificado exitosamente'),
                ],
              ),
              backgroundColor: const Color(0xFF2E7D32),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
            ),
          );
        },
        onReject: () {
          Navigator.pop(context);
          _showRejectSheet();
        },
      ),
    );
  }

  void _showRejectSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _RejectSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildDocumentSelector(),
              _buildProgressBar(),
              Expanded(child: _buildDocumentViewer()),
              _buildPageIndicator(),
              const SizedBox(height: 12),
              _buildActionBar(),
              const SizedBox(height: 16),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: Color(0xFF1A1A2E)),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF283593)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.verified_user_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VERIFICACIONES',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  'GET /api/admin/verifications',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    fontFamily: 'Courier',
                  ),
                ),
              ],
            ),
          ),
          // Badge de pendientes
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pending_outlined,
                    size: 12, color: Color(0xFFE65100)),
                const SizedBox(width: 4),
                Text(
                  '${_documents.length} pendientes',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFE65100),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Selector de documentos ───────────────────────────────────────────────────

  Widget _buildDocumentSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review documents',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(_documents.length, (i) {
              final doc = _documents[i];
              final selected = _selectedDoc == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDoc = i;
                      _selectedPage = 0;
                    });
                    _pageController.jumpToPage(0);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: EdgeInsets.only(right: i < _documents.length - 1 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF1A237E)
                          : const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF1A237E)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.insert_drive_file_outlined,
                          size: 14,
                          color: selected
                              ? Colors.white70
                              : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doc.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? Colors.white
                                      : const Color(0xFF1A1A2E),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                doc.type,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: selected
                                      ? Colors.white60
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Barra de progreso ────────────────────────────────────────────────────────

  Widget _buildProgressBar() {
    final total = _currentDoc.totalPages;
    final progress = (_selectedPage + 1) / total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(
            'Página ${_selectedPage + 1} de $total',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF1A237E)),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${(progress * 100).round()}%',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1A237E),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Visor de documentos ──────────────────────────────────────────────────────

  Widget _buildDocumentViewer() {
    final pages = _currentDoc.pages;
    return PageView.builder(
      controller: _pageController,
      itemCount: pages.length,
      onPageChanged: (i) => setState(() => _selectedPage = i),
      itemBuilder: (context, index) {
        final page = pages[index];
        final isActive = index == _selectedPage;
        return AnimatedScale(
          scale: isActive ? 1.0 : 0.95,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: AnimatedBuilder(
            animation: _floatAnim,
            builder: (context, child) {
              return Transform.translate(
                offset: isActive ? Offset(0, _floatAnim.value) : Offset.zero,
                child: child,
              );
            },
            child: _DocumentCard(page: page, index: index),
          ),
        );
      },
    );
  }

  // ── Indicador de página ──────────────────────────────────────────────────────

  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_currentDoc.totalPages, (i) {
          final selected = _selectedPage == i;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: selected ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF1A237E)
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }

  // ── Barra de acciones ────────────────────────────────────────────────────────

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Botón Verificar
          Expanded(
            flex: 3,
            child: AnimatedBuilder(
              animation: _approveController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 - (_approveController.value * 0.05),
                  child: child,
                );
              },
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A237E), Color(0xFF283593)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A237E).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _onVerificar,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.verified_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Verificar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Botón rechazar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFEF9A9A), width: 1.5),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _showRejectSheet,
                child: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFFC62828),
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Botón compartir
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: Colors.grey.shade300, width: 1.5),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {},
                child: Icon(Icons.share_outlined,
                    color: Colors.grey.shade600, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Nav ──────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    const items = [
      (Icons.home_rounded, 'Inicio'),
      (Icons.bar_chart_rounded, 'Reportes'),
      (Icons.chat_bubble_outline_rounded, 'Soporte'),
      (Icons.verified_user_outlined, 'Verificar'),
      (Icons.person_outline_rounded, 'Perfil'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 58,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final selected = _selectedNav == i;
              final color = selected
                  ? const Color(0xFF1A237E)
                  : Colors.grey.shade500;
              return GestureDetector(
                onTap: () => setState(() => _selectedNav = i),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 60,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(items[i].$1, color: color, size: 22),
                      const SizedBox(height: 3),
                      Text(
                        items[i].$2,
                        style: TextStyle(
                          fontSize: 9,
                          color: color,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─── Tarjeta de documento ──────────────────────────────────────────────────────

class _DocumentCard extends StatelessWidget {
  final DocumentPage page;
  final int index;
  const _DocumentCard({required this.page, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: page.accentColor.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Cabecera del documento
            Container(
              height: 6,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    page.accentColor,
                    page.accentColor.withValues(alpha: 0.4),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Membrete simulado
                    _buildLetterhead(),
                    const SizedBox(height: 16),
                    // Título del documento
                    _buildDocumentTitle(),
                    const SizedBox(height: 16),
                    // Contenido simulado
                    _buildDocumentBody(),
                    const Spacer(),
                    // Footer
                    _buildDocumentFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLetterhead() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: page.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(page.icon, color: page.accentColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 8,
                width: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 6,
                width: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
        // Sello
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: page.accentColor.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: Center(
            child: CustomPaint(
              size: const Size(32, 32),
              painter: _SealPainter(color: page.accentColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          page.title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: page.accentColor,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          page.subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Divider(color: Colors.grey.shade200, thickness: 1),
      ],
    );
  }

  Widget _buildDocumentBody() {
    return Column(
      children: [
        // Filas de texto simuladas
        ...List.generate(5, (i) => _TextLine(
          width: i % 3 == 0 ? 1.0 : (i % 3 == 1 ? 0.8 : 0.6),
          indent: i == 2 || i == 4,
        )),
        const SizedBox(height: 12),
        // Tabla simulada
        _buildSimulatedTable(),
        const SizedBox(height: 12),
        ...List.generate(3, (i) => _TextLine(
          width: i == 2 ? 0.5 : 0.9,
          indent: false,
        )),
      ],
    );
  }

  Widget _buildSimulatedTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: List.generate(3, (row) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: row == 0
                  ? page.accentColor.withValues(alpha: 0.06)
                  : Colors.transparent,
              border: row < 2
                  ? Border(
                      bottom: BorderSide(
                          color: Colors.grey.shade200, width: 0.5))
                  : null,
            ),
            child: Row(
              children: List.generate(3, (col) {
                return Expanded(
                  child: Container(
                    height: 6,
                    margin: EdgeInsets.only(right: col < 2 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: row == 0
                          ? page.accentColor.withValues(alpha: 0.3)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDocumentFooter() {
    return Column(
      children: [
        Divider(color: Colors.grey.shade200, thickness: 1),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Firma simulada
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SignatureLine(color: page.accentColor),
                const SizedBox(height: 4),
                Container(
                  height: 5,
                  width: 70,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
            // Número de página
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: page.accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Pág. ${index + 1}',
                style: TextStyle(
                  fontSize: 10,
                  color: page.accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Widgets auxiliares del documento ──────────────────────────────────────────

class _TextLine extends StatelessWidget {
  final double width;
  final bool indent;
  const _TextLine({required this.width, required this.indent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: indent ? 14 : 0, bottom: 5),
      child: FractionallySizedBox(
        widthFactor: width,
        alignment: Alignment.centerLeft,
        child: Container(
          height: 6,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

class _SignatureLine extends StatelessWidget {
  final Color color;
  const _SignatureLine({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 20,
      child: CustomPaint(painter: _SignaturePainter(color: color)),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final Color color;
  const _SignaturePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height * 0.6)
      ..cubicTo(
        size.width * 0.2, size.height * 0.1,
        size.width * 0.3, size.height * 0.9,
        size.width * 0.5, size.height * 0.5,
      )
      ..cubicTo(
        size.width * 0.65, size.height * 0.2,
        size.width * 0.8, size.height * 0.8,
        size.width, size.height * 0.4,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _SealPainter extends CustomPainter {
  final Color color;
  const _SealPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(center, size.width * 0.4, paint);
    paint.color = color.withValues(alpha: 0.5);

    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi * 2) / 8;
      final x1 = center.dx + size.width * 0.25 * math.cos(angle);
      final y1 = center.dy + size.width * 0.25 * math.sin(angle);
      final x2 = center.dx + size.width * 0.38 * math.cos(angle);
      final y2 = center.dy + size.width * 0.38 * math.sin(angle);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }

    paint
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size.width * 0.12, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Dialogo de confirmación ───────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String docName;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  const _ConfirmDialog({
    required this.docName,
    required this.onConfirm,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFE8EAF6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.verified_user_rounded,
                  color: Color(0xFF1A237E), size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Confirmar Verificación',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '¿Estás seguro de verificar\n"$docName"?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC62828),
                      side: const BorderSide(color: Color(0xFFEF9A9A)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Rechazar',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Confirmar',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sheet de rechazo ──────────────────────────────────────────────────────────

class _RejectSheet extends StatefulWidget {
  const _RejectSheet();

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  int? _selectedReason;
  final _controller = TextEditingController();

  final List<String> _reasons = [
    'Documento ilegible o borroso',
    'Información incompleta',
    'Documento vencido',
    'No corresponde al tipo solicitado',
    'Posible falsificación',
    'Otro motivo',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
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
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.cancel_outlined,
                    color: Color(0xFFC62828), size: 20),
                SizedBox(width: 8),
                Text(
                  'Motivo de Rechazo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ..._reasons.asMap().entries.map((e) {
            final selected = _selectedReason == e.key;
            return GestureDetector(
              onTap: () => setState(() => _selectedReason = e.key),
              child: Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 3),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFFFEBEE)
                      : const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFFEF9A9A)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected
                          ? const Color(0xFFC62828)
                          : Colors.grey.shade400,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 13,
                        color: selected
                            ? const Color(0xFFC62828)
                            : const Color(0xFF1A1A2E),
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: TextField(
              controller: _controller,
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Comentario adicional (opcional)...',
                hintStyle:
                    TextStyle(fontSize: 13, color: Colors.grey.shade400),
                filled: true,
                fillColor: const Color(0xFFF5F5F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selectedReason != null
                    ? () => Navigator.pop(context)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828),
                  disabledBackgroundColor: Colors.grey.shade200,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Enviar Rechazo',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

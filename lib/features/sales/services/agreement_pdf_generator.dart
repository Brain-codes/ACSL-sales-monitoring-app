import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';

import '../models/sale_model.dart';

/// Pixel-faithful replica of the atmosfair "Improved Cook Stoves Programme for
/// Nigeria — User Agreement / Receipt" paper form, generated in code from a
/// [SaleModel]. This is the Flutter port of the web AgreementPDFGenerator.ts —
/// it draws on a raw PDF canvas in millimetre coordinates (top-down origin,
/// matching jsPDF) so the output matches the web document.
class AgreementPDFGenerator {
  // ── atmosfair / brand colours ───────────────────────────────────────────────
  static const _gray = PdfColor.fromInt(0xFFD2D6DC); // N/A shaded cells
  static const _green = PdfColor.fromInt(0xFF78AA28); // atmosfair wordmark
  static const _darkGreen = PdfColor.fromInt(0xFF3C6E14);
  static const _blue = PdfColor.fromInt(0xFF07376A); // section bars
  static const _blueHeader = PdfColor.fromInt(0xFF194977); // table header
  static const _blueLight = PdfColor.fromInt(0xFFE8F0FA); // label cells
  static const _border = PdfColor.fromInt(0xFF788CA5); // muted blue grid lines
  static const _grayText = PdfColor.fromInt(0xFF3C4655);
  static const _white = PdfColors.white;
  static const _black = PdfColors.black;

  static String _formatDate(DateTime? d) =>
      d != null ? DateFormat('dd MMM yyyy').format(d) : '';

  static String _formatAmount(double? v) =>
      v != null ? NumberFormat.decimalPattern('en_NG').format(v) : '';

  // Split a single full name into [surname, firstName(s)] — first token is the
  // surname (common ordering on these Nigerian field forms).
  static List<String> _splitName(String? name) {
    if (name == null || name.trim().isEmpty) return ['', ''];
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return [parts[0], ''];
    return [parts[0], parts.sublist(1).join(' ')];
  }

  /// Builds the agreement PDF bytes for [sale].
  static Future<List<int>> generate(SaleModel sale) async {
    final doc = PdfDocument();
    final c = _Canvas(doc);

    // ── Layout constants ──────────────────────────────────────────────────────
    const L = 8.0; // left margin
    const R = 202.0; // right edge
    const W = R - L; // content width
    const cLabel = L; // person-table column boundaries
    const cUser = 56.0;
    const cBuyer = 152.0;

    c.setLineWidth(0.3);
    c.setDraw(_border);

    // ── Gather data ───────────────────────────────────────────────────────────
    final userName = _splitName(sale.endUserName);
    final buyerName = _splitName(sale.contactPerson);
    final userSurname = userName[0], userFirst = userName[1];
    final buyerSurname = buyerName[0], buyerFirst = buyerName[1];
    final buyerIsUser = sale.contactPerson == null ||
        sale.contactPerson!.trim().isEmpty ||
        sale.contactPerson!.trim() == (sale.endUserName ?? '').trim();
    // Mobile SaleModel does not carry per-term acceptance flags, so all unticked.
    const terms = <String, bool>{};
    final isCredit = sale.isInstallment == true || sale.selectedModelId != null;
    final potQty = sale.potQuantity ?? -1;
    final creatorName = sale.creatorRole == 'agent'
        ? (sale.creatorName ?? '')
        : (sale.creatorName != null ? 'Admin' : '');

    double y = 8;

    // ── Header: logos + title ─────────────────────────────────────────────────
    const headerH = 20.0;
    // atmosfair wordmark (the web /logo.png asset isn't bundled on mobile).
    c.setFont(bold: true);
    c.setFontSize(20);
    c.setText(_darkGreen);
    c.text('atmosfair', L, y + 12);
    c.setDraw(_green);
    c.setLineWidth(1);
    c.line(L, y + 14, L + 40, y + 14);
    c.setDraw(_border);
    c.setLineWidth(0.3);

    // Title (center)
    c.setFont(bold: true);
    c.setFontSize(10);
    c.setText(_grayText);
    c.text('Improved Cook Stoves Programme for Nigeria', 105, y + 4,
        align: _Align.center);
    c.setFontSize(18);
    c.setText(_blue);
    c.text('User Agreement / Receipt', 105, y + 13, align: _Align.center);
    c.setText(_black);

    y += headerH;

    // ── Contact bar ───────────────────────────────────────────────────────────
    const barH = 7.0;
    c.fillRect(L, y, W, barH, _blueLight);
    c.box(L, y, W, barH);
    c.setFont(bold: true);
    c.setFontSize(8);
    c.setText(_blue);
    c.text(
      "No. 22, Ja'Afaru Mai Malari Road, Bompai Industrial Area, Kano - Nigeria  |  Tel: 09120135750, 09120135754, 08121726360",
      105,
      y + 4.6,
      align: _Align.center,
    );
    c.setText(_black);
    y += barH;

    // ── People table header row ───────────────────────────────────────────────
    const thH = 9.0;
    // diagonal corner cell
    c.fillRect(cLabel, y, cUser - cLabel, thH, _blueHeader);
    c.box(cLabel, y, cUser - cLabel, thH);
    c.setDraw(_white);
    c.line(cLabel, y, cUser, y + thH); // diagonal
    c.setDraw(_border);
    // User details
    c.fillRect(cUser, y, cBuyer - cUser, thH, _blueHeader);
    c.box(cUser, y, cBuyer - cUser, thH);
    c.setFont(bold: true);
    c.setFontSize(9);
    c.setText(_white);
    c.text('User details', cUser + 2, y + 5.5);
    // Buyer details
    c.fillRect(cBuyer, y, R - cBuyer, thH, _blueHeader);
    c.box(cBuyer, y, R - cBuyer, thH);
    c.setFontSize(8);
    c.text('Buyer details: (if', cBuyer + 2, y + 4);
    c.text('not user)', cBuyer + 2, y + 7.5);
    c.setText(_black);
    y += thH;

    // Helper to render a standard person row.
    void personRow(String label, String userVal, String? buyerVal,
        {double h = 7}) {
      // label cell (light blue)
      c.fillRect(cLabel, y, cUser - cLabel, h, _blueLight);
      c.box(cLabel, y, cUser - cLabel, h);
      c.setFont(bold: true);
      c.setFontSize(7.5);
      c.setText(_blue);
      final labelLines = c.splitText(label, cUser - cLabel - 3);
      c.textLines(labelLines, cLabel + 1.5,
          y + h / 2 - (labelLines.length - 1) * 1.5 + 1);
      c.setText(_black);
      // user cell (white)
      c.box(cUser, y, cBuyer - cUser, h);
      c.setFont(bold: false);
      c.setFontSize(8);
      if (userVal.isNotEmpty) c.text(userVal, cUser + 2, y + h / 2 + 1.2);
      // buyer cell
      if (buyerVal == 'N/A') {
        c.fillRect(cBuyer, y, R - cBuyer, h, _gray);
        c.box(cBuyer, y, R - cBuyer, h);
        c.setFont(bold: false);
        c.setFontSize(8);
        c.text('N/A', (cBuyer + R) / 2, y + h / 2 + 1.2, align: _Align.center);
      } else {
        c.box(cBuyer, y, R - cBuyer, h);
        c.setFont(bold: false);
        c.setFontSize(8);
        if (buyerVal != null && buyerVal.isNotEmpty) {
          c.text(buyerVal, cBuyer + 2, y + h / 2 + 1.2);
        }
      }
      y += h;
    }

    String buyerCell(String v) => buyerIsUser ? '' : v;

    personRow('SURNAME', userSurname, buyerCell(buyerSurname));
    personRow('FIRST NAME', userFirst, buyerCell(buyerFirst));

    // RESIDENTIAL ADDRESS — tall, buyer side is 3 stacked N/A cells
    {
      const h = 16.0;
      c.fillRect(cLabel, y, cUser - cLabel, h, _blueLight);
      c.box(cLabel, y, cUser - cLabel, h);
      c.setFont(bold: true);
      c.setFontSize(7.5);
      c.setText(_blue);
      c.text('RESIDENTIAL ADDRESS', cLabel + 1.5, y + h / 2 + 1);
      c.setText(_black);
      c.box(cUser, y, cBuyer - cUser, h);
      c.setFont(bold: false);
      c.setFontSize(8);
      final addr = sale.address ?? '';
      if (addr.isNotEmpty) {
        final lines = c.splitText(addr, cBuyer - cUser - 4);
        c.textLines(lines.take(3).toList(), cUser + 2, y + 5);
      }
      // buyer: three N/A sub-cells
      const sub = h / 3;
      for (int i = 0; i < 3; i++) {
        c.fillRect(cBuyer, y + i * sub, R - cBuyer, sub, _gray);
        c.box(cBuyer, y + i * sub, R - cBuyer, sub);
        c.text('N/A', (cBuyer + R) / 2, y + i * sub + sub / 2 + 1.2,
            align: _Align.center);
      }
      y += h;
    }

    personRow('LGA', sale.lga ?? '', 'N/A');
    personRow('STATE', sale.state ?? '', 'N/A');
    personRow('TELEPHONE NUMBER', sale.phone ?? '',
        buyerCell(sale.contactPhone ?? ''));
    personRow('OTHER TELEPHONE NUMBER', sale.otherPhone ?? '', '');
    personRow('SALES PARTNER', sale.partnerName ?? '', 'N/A');
    personRow('RETAILER / SALES BRANCH / AGENCY / CSO',
        sale.retailerBranch ?? '', 'N/A', h: 9);

    // ── STOVE SET AND PAYMENT OPTION bar ──────────────────────────────────────
    c.fillRect(L, y, W, 6, _blue);
    c.box(L, y, W, 6);
    c.setFont(bold: true);
    c.setFontSize(8.5);
    c.setText(_white);
    c.text('STOVE SET AND PAYMENT OPTION', L + 1.5, y + 4.2);
    c.setText(_black);
    y += 6;

    // stove set row — 4 columns
    {
      const h = 24.0;
      const c1 = L;
      const c2 = L + 62;
      const c3 = L + 112;
      const c4 = R - 42;
      c.box(c1, y, c2 - c1, h);
      c.box(c2, y, c3 - c2, h);
      c.box(c3, y, c4 - c3, h);
      c.box(c4, y, R - c4, h);
      c.setFont(bold: false);
      c.setFontSize(8);
      // col1 Stove type
      c.text('Stove type:', c1 + 2, y + 6);
      c.text('Save80', c1 + 2, y + 13);
      c.line(c1 + 18, y + 12.5, c2 - 8, y + 12.5);
      c.checkbox(c2 - 6, y + 10.5, true);
      // col2 pots
      c.text('Pots quantity:', c2 + 2, y + 6);
      const pots = ['0 pots', '1 pot', '2 pots'];
      for (int i = 0; i < pots.length; i++) {
        final py = y + 11 + i * 5;
        c.text(pots[i], c2 + 2, py + 0.5);
        c.line(c2 + 14, py, c3 - 8, py);
        c.checkbox(c3 - 6, py - 2.6, potQty == i, size: 3.2);
      }
      // col3 heat retention
      c.text('Heat retention device', c3 + 2, y + 7);
      c.text('Wonderbox', c3 + 2, y + 14);
      c.line(c3 + 24, y + 13.5, c4 - 8, y + 13.5);
      c.checkbox(c4 - 6, y + 11.5, sale.heatRetentionDevice == true);
      // col4 cash/credit
      c.text('CASH', c4 + 2, y + 6);
      c.text('PURCHASE', c4 + 2, y + 10);
      c.checkbox(R - 6, y + 6.5, !isCredit);
      c.text('CREDIT', c4 + 2, y + 17);
      c.text('PURCHASE', c4 + 2, y + 21);
      c.checkbox(R - 6, y + 17.5, isCredit);
      y += h;
    }

    // ── Sales date / serial / amount ──────────────────────────────────────────
    {
      const hH = 9.0;
      const v = 15.0;
      const a1 = L;
      const a2 = L + 70;
      const a3 = R - 50;
      c.fillRect(a1, y, a2 - a1, hH, _blueLight);
      c.fillRect(a2, y, a3 - a2, hH, _blueLight);
      c.fillRect(a3, y, R - a3, hH, _blueLight);
      c.box(a1, y, a2 - a1, hH);
      c.box(a2, y, a3 - a2, hH);
      c.box(a3, y, R - a3, hH);
      c.setFont(bold: true);
      c.setFontSize(8);
      c.setText(_blue);
      c.text('SALES DATE', a1 + 2, y + 5.4);
      c.text('STOVE SERIAL NUMBER', a2 + 2, y + 5.4);
      c.text('AMOUNT PAID', a3 + 2, y + 4);
      c.setFontSize(6.5);
      c.text('(Naira)', a3 + 2, y + 7.2);
      c.setText(_black);
      y += hH;
      // value cells
      c.box(a1, y, a2 - a1, v);
      c.box(a2, y, a3 - a2, v);
      c.box(a3, y, R - a3, v);
      c.setFont(bold: false);
      c.setFontSize(9);
      c.text(_formatDate(sale.salesDate), a1 + 2, y + 8);
      c.text(sale.stoveSerialNo ?? '', a2 + 2, y + 8);
      c.text(_formatAmount(sale.amount), a3 + 2, y + 8);
      y += v;
    }

    // ── Terms and conditions ──────────────────────────────────────────────────
    y += 2;
    c.setFont(bold: true);
    c.setFontSize(8.5);
    c.setText(_blue);
    c.text('TERMS AND CONDITIONS: (please tick)', L, y + 3);
    c.setText(_black);
    y += 5;

    const termList = <List<String>>[
      [
        'poaGoverned',
        'This stove is promoted and sold under the atmosfair Programme of Activities (PoA) which is governed by the UN Framework Convention on Climate Change (UNFCCC) and Gold Standard for the Global Goals. I hereby recognize that the stove is subsidized by Carbon Credits.'
      ],
      [
        'monitoring',
        'I agree to cooperate with the distributor and the cooperating managing entity (atmosfair gGmbH) for monitoring purposes.'
      ],
      ['noResell', 'I agree not to resell the stove.'],
      [
        'emissionReductions',
        'I agree not to claim any emission reductions for the use of the efficient cook stove but cede the emission reductions the stove generates to the cooperating managing entity (atmosfair gGmbH) of the Programme of Activities (PoA).'
      ],
      ['noExport', 'I agree not to take the stove outside of Nigeria.'],
      [
        'demonstration',
        'I have received a sufficient demonstration and explanation for efficient firewood stove usage.'
      ],
    ];

    c.setFont(bold: false);
    c.setFontSize(8);
    for (final t in termList) {
      final key = t[0], text = t[1];
      c.checkbox(L + 4, y, terms[key] == true, size: 3.2);
      final lines = c.splitText(text, W - 12);
      c.textLines(lines, L + 9, y + 3);
      y += (lines.length * 3.7).clamp(4, double.infinity) + 1.5;
    }

    // ── Predominant previous stove ────────────────────────────────────────────
    y += 1;
    final prevBoxTop = y;
    c.setFont(bold: false);
    c.setFontSize(8);
    final intro = c.splitText(
      'The new Save80 user was predominantly using the following stove (the stove they were cooking most of the meals with):',
      W - 4,
    );
    c.textLines(intro, L + 2, y + 4);
    y += intro.length * 3.7 + 3;
    // three columns
    const pCol = W / 3;
    final prevType = (sale.previousStoveType ?? '').toLowerCase();
    final colTop = y;
    const colH = 14.0;
    for (int i = 0; i < 3; i++) {
      c.box(L + i * pCol, colTop, pCol, colH);
    }
    c.setFont(bold: true);
    c.setFontSize(8);
    c.setText(_blue);
    c.checkbox(L + 2, colTop + 2, prevType == 'charcoal', size: 3.2);
    c.text('Charcoal stove', L + 7, colTop + 4.5);
    c.checkbox(L + pCol + 2, colTop + 2, prevType == 'wood_stove', size: 3.2);
    c.text('Wood Stove', L + pCol + 7, colTop + 4.5);
    c.setText(_black);
    c.setFont(bold: false);
    c.setFontSize(7);
    c.text('(3 stone or similar)', L + pCol + 7, colTop + 8);
    c.setFont(bold: true);
    c.setFontSize(8);
    c.setText(_blue);
    c.checkbox(L + 2 * pCol + 2, colTop + 2, prevType == 'other', size: 3.2);
    c.text('Other', L + 2 * pCol + 7, colTop + 4.5);
    c.setText(_black);
    c.setFont(bold: false);
    c.setFontSize(7);
    c.text('(please specify)', L + 2 * pCol + 7, colTop + 8);
    // outer border around predominant section
    c.box(L, prevBoxTop, W, colTop + colH - prevBoxTop);
    y = colTop + colH;

    // ── Meal/fuel/location questions ──────────────────────────────────────────
    const qH = 6.0;
    final qRows = <List<String>>[
      [
        'How many meals do you prepare usually on your stove?',
        sale.mealsPerDay ?? ''
      ],
      ['Where do you get your cooking fuel from?', sale.cookingFuelSource ?? ''],
      ['Where do you cook usually?', sale.cookingLocation ?? ''],
    ];
    c.setFont(bold: false);
    c.setFontSize(8);
    for (final q in qRows) {
      c.box(L, y, W, qH);
      c.text(q[0], L + 2, y + 4);
      if (q[1].isNotEmpty) c.text(q[1], L + 95, y + 4);
      y += qH;
    }

    // ── Signature + agent name ────────────────────────────────────────────────
    {
      const h = 18.0;
      const half = W / 2;
      c.fillRect(L, y, W, h, _blueLight);
      c.box(L, y, half, h);
      c.box(L + half, y, half, h);
      c.setFont(bold: true);
      c.setFontSize(8);
      c.setText(_blue);
      c.text("BUYER'S SIGNATURE:", L + 2, y + 4);
      c.text("SALES AGENT'S NAME:", L + half + 2, y + 4);
      c.setText(_black);
      // Signature image isn't available on the mobile SaleModel; left blank.
      c.setFont(bold: false);
      c.setFontSize(9);
      if (creatorName.isNotEmpty) c.text(creatorName, L + half + 4, y + 12);
      y += h;
    }

    return doc.save();
  }
}

enum _Align { left, center }

/// Thin wrapper over [PdfGraphics] that mirrors jsPDF's API: millimetre units
/// with a top-down origin (y grows downward), so the porting maths from the web
/// generator stays one-to-one.
class _Canvas {
  _Canvas(PdfDocument doc)
      : _g = PdfPage(doc, pageFormat: PdfPageFormat.a4).getGraphics(),
        _helv = PdfFont.helvetica(doc),
        _helvBold = PdfFont.helveticaBold(doc) {
    _font = _helv;
  }

  static const double _mm = PdfPageFormat.mm;
  static const double _pageHmm = 297; // A4 height in mm

  final PdfGraphics _g;
  final PdfFont _helv;
  final PdfFont _helvBold;

  PdfColor _draw = PdfColors.black;
  PdfColor _textColor = PdfColors.black;
  double _lineWidth = 0.3;
  late PdfFont _font;
  double _fontSize = 8;

  double _y(double topMm) => (_pageHmm - topMm) * _mm;

  void setDraw(PdfColor c) => _draw = c;
  void setText(PdfColor c) => _textColor = c;
  void setLineWidth(double w) => _lineWidth = w;
  void setFont({required bool bold}) => _font = bold ? _helvBold : _helv;
  void setFontSize(double s) => _fontSize = s;

  void fillRect(double x, double y, double w, double h, PdfColor color) {
    _g.setFillColor(color);
    _g.drawRect(x * _mm, _y(y + h), w * _mm, h * _mm);
    _g.fillPath();
  }

  void box(double x, double y, double w, double h) {
    _g.setStrokeColor(_draw);
    _g.setLineWidth(_lineWidth * _mm);
    _g.drawRect(x * _mm, _y(y + h), w * _mm, h * _mm);
    _g.strokePath();
  }

  void line(double x1, double y1, double x2, double y2) {
    _g.setStrokeColor(_draw);
    _g.setLineWidth(_lineWidth * _mm);
    _g.drawLine(x1 * _mm, _y(y1), x2 * _mm, _y(y2));
    _g.strokePath();
  }

  void text(String s, double x, double y, {_Align align = _Align.left}) {
    if (s.isEmpty) return;
    _g.setFillColor(_textColor);
    var dx = 0.0;
    if (align == _Align.center) {
      dx = -_font.stringMetrics(s).width * _fontSize / 2;
    }
    _g.drawString(_font, _fontSize, s, x * _mm + dx, _y(y));
  }

  /// Draws pre-wrapped [lines] starting at baseline [yTop], stepping down by a
  /// line height derived from the current font size (matches jsPDF spacing).
  void textLines(List<String> lines, double x, double yTop) {
    final gap = _fontSize * 1.15 / (72 / 25.4); // mm per line
    for (int i = 0; i < lines.length; i++) {
      text(lines[i], x, yTop + i * gap);
    }
  }

  /// Word-wraps [s] to [maxWidthMm] using the current font/size (jsPDF's
  /// splitTextToSize equivalent).
  List<String> splitText(String s, double maxWidthMm) {
    final maxW = maxWidthMm * _mm;
    final words = s.split(' ');
    final lines = <String>[];
    var cur = '';
    for (final wd in words) {
      final test = cur.isEmpty ? wd : '$cur $wd';
      if (_font.stringMetrics(test).width * _fontSize <= maxW) {
        cur = test;
      } else {
        if (cur.isNotEmpty) lines.add(cur);
        cur = wd;
      }
    }
    if (cur.isNotEmpty) lines.add(cur);
    return lines.isEmpty ? [''] : lines;
  }

  void checkbox(double x, double y, bool checked, {double size = 3.4}) {
    _g.setLineWidth(0.3 * _mm);
    _g.setStrokeColor(_blue);
    _g.drawRect(x * _mm, _y(y + size), size * _mm, size * _mm);
    _g.strokePath();
    if (checked) {
      _g.setLineWidth(0.7 * _mm);
      _g.setStrokeColor(_blue);
      _g.drawLine((x + 0.7) * _mm, _y(y + size * 0.55),
          (x + size * 0.4) * _mm, _y(y + size - 0.6));
      _g.drawLine((x + size * 0.4) * _mm, _y(y + size - 0.6),
          (x + size - 0.3) * _mm, _y(y + 0.5));
      _g.strokePath();
      _g.setLineWidth(0.3 * _mm);
    }
    _g.setStrokeColor(_draw);
  }

  static const _blue = PdfColor.fromInt(0xFF07376A);
}

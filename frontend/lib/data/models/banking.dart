import 'package:equatable/equatable.dart';

import 'attachment.dart';
import 'json.dart';

const kCardBlockReasons = ['lost', 'stolen', 'blocked', 'damaged', 'swallowed_by_atm', 'fraud_suspected'];

/// `CardInfo` of openapi.yaml.
class CardInfo extends Equatable {
  const CardInfo({required this.last4, required this.type, required this.status});

  factory CardInfo.fromJson(Json j) =>
      CardInfo(last4: j['last4'] as String, type: j['type'] as String, status: j['status'] as String);

  final String last4;
  final String type;
  final String status;

  Json toJson() => {'last4': last4, 'type': type, 'status': status};

  @override
  List<Object?> get props => [last4, type, status];
}

/// `CardBlockRequest` of openapi.yaml. Holds the PIN only for the time of the request:
/// never stored in a BLoC state, never logged ([toString] redacts it).
class CardBlockRequest {
  const CardBlockRequest({
    this.conversationId,
    required this.accountNumber,
    this.pin,
    this.dateOfBirth,
    this.cardLast4,
    required this.reason,
    required this.lang,
  }) : assert((pin == null) != (dateOfBirth == null), 'exactly one of pin / dateOfBirth');

  final String? conversationId;
  final String accountNumber;
  final String? pin;

  /// YYYY-MM-DD
  final String? dateOfBirth;
  final String? cardLast4;
  final String reason;
  final String lang;

  Json toJson() => {
        'conversation_id': conversationId,
        'account_number': accountNumber,
        'pin': pin,
        'date_of_birth': dateOfBirth,
        'card_last4': cardLast4,
        'reason': reason,
        'lang': lang,
      };

  @override
  String toString() => 'CardBlockRequest(account: $accountNumber, reason: $reason, secret: ••••)';
}

/// `CardBlockPending` of openapi.yaml.
class CardBlockPending extends Equatable {
  const CardBlockPending({required this.confirmationId, required this.expiresAt, required this.card, required this.message});

  factory CardBlockPending.fromJson(Json j) => CardBlockPending(
        confirmationId: j['confirmation_id'] as String,
        expiresAt: parseTs(j['expires_at']),
        card: CardInfo.fromJson(j['card'] as Json),
        message: j['message'] as String,
      );

  final String confirmationId;
  final DateTime expiresAt;
  final CardInfo card;
  final String message;

  @override
  List<Object?> get props => [confirmationId, expiresAt, card, message];
}

/// `CardBlockResult` of openapi.yaml.
class CardBlockResult extends Equatable {
  const CardBlockResult({required this.reference, required this.card, required this.blockedAt, required this.message});

  factory CardBlockResult.fromJson(Json j) => CardBlockResult(
        reference: j['reference'] as String,
        card: CardInfo.fromJson(j['card'] as Json),
        blockedAt: parseTs(j['blocked_at']),
        message: j['message'] as String,
      );

  final String reference;
  final CardInfo card;
  final DateTime blockedAt;
  final String message;

  @override
  List<Object?> get props => [reference, card, blockedAt, message];
}

/// `LoanProduct` of openapi.yaml.
class LoanProduct extends Equatable {
  const LoanProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.annualRatePct,
    required this.minAmount,
    required this.maxAmount,
    required this.minTermMonths,
    required this.maxTermMonths,
    required this.requirements,
  });

  factory LoanProduct.fromJson(Json j) => LoanProduct(
        id: j['id'] as String,
        name: j['name'] as String,
        description: j['description'] as String,
        annualRatePct: toDouble(j['annual_rate_pct']),
        minAmount: j['min_amount'] as int,
        maxAmount: j['max_amount'] as int,
        minTermMonths: j['min_term_months'] as int,
        maxTermMonths: j['max_term_months'] as int,
        requirements: parseStrings(j['requirements']),
      );

  final String id;
  final String name;
  final String description;
  final double annualRatePct;
  final int minAmount;
  final int maxAmount;
  final int minTermMonths;
  final int maxTermMonths;
  final List<String> requirements;

  Json toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'annual_rate_pct': annualRatePct,
        'min_amount': minAmount,
        'max_amount': maxAmount,
        'min_term_months': minTermMonths,
        'max_term_months': maxTermMonths,
        'requirements': requirements,
        'fictional': true,
      };

  @override
  List<Object?> get props => [id, name, description, annualRatePct, minAmount, maxAmount, minTermMonths, maxTermMonths, requirements];
}

/// `LoanSimulation` of openapi.yaml (F6).
class LoanSimulation extends Equatable {
  const LoanSimulation({
    required this.productId,
    required this.productName,
    required this.amount,
    required this.termMonths,
    required this.annualRatePct,
    required this.monthlyPayment,
    required this.totalPayment,
    required this.totalInterest,
    required this.explanation,
    required this.lang,
    this.pdf,
  });

  factory LoanSimulation.fromJson(Json j) => LoanSimulation(
        productId: j['product_id'] as String,
        productName: j['product_name'] as String,
        amount: j['amount'] as int,
        termMonths: j['term_months'] as int,
        annualRatePct: toDouble(j['annual_rate_pct']),
        monthlyPayment: j['monthly_payment'] as int,
        totalPayment: j['total_payment'] as int,
        totalInterest: j['total_interest'] as int,
        explanation: j['explanation'] as String,
        lang: j['lang'] as String,
        pdf: j['pdf'] == null ? null : FileRef.fromJson(j['pdf'] as Json),
      );

  final String productId;
  final String productName;
  final int amount;
  final int termMonths;
  final double annualRatePct;
  final int monthlyPayment;
  final int totalPayment;
  final int totalInterest;
  final String explanation;
  final String lang;
  final FileRef? pdf;

  @override
  List<Object?> get props => [productId, productName, amount, termMonths, annualRatePct, monthlyPayment, totalPayment, totalInterest, explanation, lang, pdf];
}

/// `DayHours` of openapi.yaml; null = closed.
class DayHours extends Equatable {
  const DayHours(this.open, this.close);

  static DayHours? fromJson(Object? j) =>
      j == null ? null : DayHours((j as Json)['open'] as String, j['close'] as String);

  final String open;
  final String close;

  Json toJson() => {'open': open, 'close': close};

  @override
  List<Object?> get props => [open, close];
}

const kWeekDays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// `Branch` of openapi.yaml (F8).
class Branch extends Equatable {
  const Branch({
    required this.id,
    required this.name,
    required this.province,
    required this.town,
    required this.address,
    required this.phone,
    required this.hours,
    required this.hoursText,
    required this.services,
    required this.isOpenNow,
  });

  factory Branch.fromJson(Json j) => Branch(
        id: j['id'] as String,
        name: j['name'] as String,
        province: j['province'] as String,
        town: j['town'] as String,
        address: j['address'] as String,
        phone: j['phone'] as String,
        hours: {for (final d in kWeekDays) d: DayHours.fromJson((j['hours'] as Json)[d])},
        hoursText: j['hours_text'] as String,
        services: parseStrings(j['services']),
        isOpenNow: j['is_open_now'] as bool,
      );

  final String id;
  final String name;
  final String province;
  final String town;
  final String address;
  final String phone;
  final Map<String, DayHours?> hours;
  final String hoursText;
  final List<String> services;
  final bool isOpenNow;

  Json toJson() => {
        'id': id,
        'name': name,
        'province': province,
        'town': town,
        'address': address,
        'phone': phone,
        'hours': hours.map((k, v) => MapEntry(k, v?.toJson())),
        'hours_text': hoursText,
        'services': services,
        'is_open_now': isOpenNow,
        'fictional': true,
      };

  @override
  List<Object?> get props => [id, name, province, town, address, phone, hours, hoursText, services, isOpenNow];
}

/// `Agent` of openapi.yaml.
class Agent extends Equatable {
  const Agent({required this.id, required this.name, required this.languages, required this.role});

  factory Agent.fromJson(Json j) => Agent(
        id: j['id'] as String,
        name: j['name'] as String,
        languages: parseStrings(j['languages']),
        role: j['role'] as String,
      );

  final String id;
  final String name;
  final List<String> languages;
  final String role;

  Json toJson() => {'id': id, 'name': name, 'languages': languages, 'role': role};

  @override
  List<Object?> get props => [id, name, languages, role];
}

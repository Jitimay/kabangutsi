import 'package:equatable/equatable.dart';

import 'attachment.dart';
import 'json.dart';

const kTicketCategories = ['fees', 'card', 'loan', 'account', 'service_quality', 'mobile_banking', 'atm', 'other'];
const kTicketStatuses = ['open', 'in_progress', 'resolved', 'closed'];
const kUrgencies = ['low', 'medium', 'high', 'critical'];

/// `Ticket` of ws_events.json.
class Ticket extends Equatable {
  const Ticket({
    required this.id,
    required this.number,
    required this.callId,
    required this.phone,
    this.customerName,
    required this.category,
    required this.urgency,
    required this.summary,
    required this.status,
    required this.lang,
    this.assignedTo,
    this.attachments = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Ticket.fromJson(Json j) => Ticket(
        id: j['id'] as String,
        number: j['number'] as String,
        callId: j['call_id'] as String?,
        phone: j['phone'] as String?,
        customerName: j['customer_name'] as String?,
        category: j['category'] as String,
        urgency: j['urgency'] as String,
        summary: j['summary'] as String,
        status: j['status'] as String,
        lang: j['lang'] as String,
        assignedTo: j['assigned_to'] as String?,
        attachments: parseList(j['attachments'], Attachment.fromJson),
        createdAt: parseTs(j['created_at']),
        updatedAt: parseTs(j['updated_at']),
      );

  final String id;
  final String number;
  final String? callId;
  final String? phone;
  final String? customerName;
  final String category;
  final String urgency;
  final String summary;
  final String status;
  final String lang;
  final String? assignedTo;
  final List<Attachment> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;

  Ticket copyWith({String? status, String? urgency, String? assignedTo, DateTime? updatedAt}) => Ticket(
        id: id,
        number: number,
        callId: callId,
        phone: phone,
        customerName: customerName,
        category: category,
        urgency: urgency ?? this.urgency,
        summary: summary,
        status: status ?? this.status,
        lang: lang,
        assignedTo: assignedTo ?? this.assignedTo,
        attachments: attachments,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Json toJson() => {
        'id': id,
        'number': number,
        'call_id': callId,
        'phone': phone,
        'customer_name': customerName,
        'category': category,
        'urgency': urgency,
        'summary': summary,
        'status': status,
        'lang': lang,
        'assigned_to': assignedTo,
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'created_at': tsOf(createdAt),
        'updated_at': tsOf(updatedAt),
      };

  @override
  List<Object?> get props => [id, number, callId, phone, customerName, category, urgency, summary, status, lang, assignedTo, attachments, createdAt, updatedAt];
}

/// `TicketCreate` of openapi.yaml.
class TicketCreate extends Equatable {
  const TicketCreate({
    this.conversationId,
    this.phone,
    required this.category,
    required this.urgency,
    required this.description,
    required this.lang,
    this.attachments = const [],
  });

  final String? conversationId;
  final String? phone;
  final String category;
  final String urgency;
  final String description;
  final String lang;
  final List<Attachment> attachments;

  Json toJson() => {
        'conversation_id': conversationId,
        'phone': phone,
        'category': category,
        'urgency': urgency,
        'description': description,
        'lang': lang,
        'attachments': attachments.map((a) => a.toJson()).toList(),
      };

  @override
  List<Object?> get props => [conversationId, phone, category, urgency, description, lang, attachments];
}

/// Query filters of `GET /v1/tickets`.
class TicketFilter extends Equatable {
  const TicketFilter({this.status, this.urgency, this.category, this.phone, this.limit = 50, this.offset = 0});

  final String? status;
  final String? urgency;
  final String? category;
  final String? phone;
  final int limit;
  final int offset;

  bool matches(Ticket t) =>
      (status == null || t.status == status) &&
      (urgency == null || t.urgency == urgency) &&
      (category == null || t.category == category) &&
      (phone == null || t.phone == phone);

  Map<String, dynamic> toQuery() => {
        if (status != null) 'status': status,
        if (urgency != null) 'urgency': urgency,
        if (category != null) 'category': category,
        if (phone != null) 'phone': phone,
        'limit': limit,
        'offset': offset,
      };

  TicketFilter copyWith({String? Function()? status, String? Function()? urgency, String? Function()? category}) => TicketFilter(
        status: status != null ? status() : this.status,
        urgency: urgency != null ? urgency() : this.urgency,
        category: category != null ? category() : this.category,
        phone: phone,
        limit: limit,
        offset: offset,
      );

  @override
  List<Object?> get props => [status, urgency, category, phone, limit, offset];
}

class TicketPage extends Equatable {
  const TicketPage({required this.items, required this.total});

  factory TicketPage.fromJson(Json j) => TicketPage(items: parseList(j['items'], Ticket.fromJson), total: j['total'] as int);

  final List<Ticket> items;
  final int total;

  @override
  List<Object?> get props => [items, total];
}

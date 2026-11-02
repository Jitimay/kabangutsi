/// Route paths. Use these constants, never string literals in widgets.
abstract final class CustomerRoutes {
  static const chat = '/chat';
  static const modelPicker = '/chat/models';
  static const call = '/call';
  static const ussd = '/ussd';
  static const services = '/services';
  static const cardBlock = '/services/card-block';
  static const loanSimulator = '/services/loan';
  static const complaint = '/services/complaint';
  static const branchFinder = '/services/branches';
  static const scanDocument = '/services/scan';
}

abstract final class AgentRoutes {
  static const queue = '/queue';
  static String callDetail(String callId) => '/queue/$callId';
  static const tickets = '/tickets';
  static const stats = '/stats';
}

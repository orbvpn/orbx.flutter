class User {
  final int id;
  final String email;
  final Subscription? subscription;

  User({required this.id, required this.email, this.subscription});
}

class Subscription {
  final String planName;
  Subscription({required this.planName});
}

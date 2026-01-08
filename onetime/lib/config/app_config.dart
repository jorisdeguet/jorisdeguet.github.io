/// Configuration globale de l'application pour le développement et le debug
class AppConfig {
  /// Active/désactive l'échange automatique de pseudo au début d'une conversation
  /// Si false, les messages pseudo ne seront pas envoyés automatiquement
  static const bool pseudoExchangeStartConversation = false;
  
  /// Active/désactive le stockage du texte en clair dans Firestore pour debug
  /// ATTENTION: Ne jamais activer en production! Compromet la sécurité
  static const bool plaintextMessageFirestore = false;
  
  /// Active/désactive les logs de debug étendus pour le chiffrement
  static const bool verboseCryptoLogs = true;
}

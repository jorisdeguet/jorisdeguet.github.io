/// One-Time Pad Encryption Library
/// 
/// Provides secure One-Time Pad encryption with:
/// - Camera-based entropy for key generation
/// - QR code-based local key exchange
/// - Multi-peer key sharing with segment allocation
/// - Firebase-based encrypted messaging
/// - Simplified authentication with pseudo
/// - Message compression for key savings

library;

// Models
export 'model_local/shared_key.dart';
export 'model_remote/key_segment.dart';
export 'model_remote/conversation.dart';
export 'model_remote/kex_session.dart';

// Services
export 'services/key_exchange_service.dart';
export 'services/key_exchange_sync_service.dart';
export 'services/key_storage_service.dart';
export 'services/crypto_service.dart';
export 'services/auth_service.dart';
export 'services/compression_service.dart';
export 'services/format_service.dart';
export 'services/conversation_service.dart';

// Screens
export 'screens/login_screen.dart';
export 'screens/home_screen.dart';
export 'screens/profile_screen.dart';
export 'screens/new_conversation_screen.dart';
export 'screens/join_conversation_screen.dart';
export 'screens/key_exchange_screen.dart';
export 'screens/conversation_detail_screen.dart';

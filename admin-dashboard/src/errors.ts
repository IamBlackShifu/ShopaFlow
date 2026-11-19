const safeMessages: Record<string, string> = {
  'auth/invalid-credential': 'The email or password is incorrect.',
  'auth/user-not-found': 'The email or password is incorrect.',
  'auth/wrong-password': 'The email or password is incorrect.',
  'auth/invalid-email': 'Enter a valid email address.',
  'auth/email-already-in-use': 'An account already exists for this email address.',
  'auth/weak-password': 'Choose a stronger password with at least 6 characters.',
  'auth/user-disabled': 'This account is currently unavailable. Contact your administrator.',
  'auth/too-many-requests': 'Too many attempts. Wait a moment and try again.',
  'auth/network-request-failed': 'Check your internet connection and try again.',
  'auth/operation-not-allowed': 'This sign-in method is currently unavailable.',
  'permission-denied': 'You do not have permission to perform this action.',
  'firestore/permission-denied': 'You do not have permission to perform this action.',
  'unauthenticated': 'Your session has expired. Sign in and try again.',
  'firestore/unauthenticated': 'Your session has expired. Sign in and try again.',
  'unavailable': 'The service is temporarily unavailable. Please try again.',
  'firestore/unavailable': 'The service is temporarily unavailable. Please try again.',
  'deadline-exceeded': 'The request took too long. Please try again.',
  'resource-exhausted': 'The service is busy. Wait a moment and try again.',
};

export function friendlyError(error: unknown, fallback: string) {
  if (!error || typeof error !== 'object') return fallback;
  const code = 'code' in error ? String(error.code).toLowerCase() : '';
  return safeMessages[code] || fallback;
}

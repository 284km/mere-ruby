/* Constants are resolved from the headers of the linked provider. */
static void x509_constants(buffer *out) {
buffer entries={0}; unsigned count=0;
#ifdef X509_V_OK
text(&entries,"V_OK"); integer(&entries,(long long)X509_V_OK); count++;
#endif
#ifdef X509_V_ERR_UNSPECIFIED
text(&entries,"V_ERR_UNSPECIFIED"); integer(&entries,(long long)X509_V_ERR_UNSPECIFIED); count++;
#endif
#ifdef X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT
text(&entries,"V_ERR_UNABLE_TO_GET_ISSUER_CERT"); integer(&entries,(long long)X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT); count++;
#endif
#ifdef X509_V_ERR_UNABLE_TO_GET_CRL
text(&entries,"V_ERR_UNABLE_TO_GET_CRL"); integer(&entries,(long long)X509_V_ERR_UNABLE_TO_GET_CRL); count++;
#endif
#ifdef X509_V_ERR_UNABLE_TO_DECRYPT_CERT_SIGNATURE
text(&entries,"V_ERR_UNABLE_TO_DECRYPT_CERT_SIGNATURE"); integer(&entries,(long long)X509_V_ERR_UNABLE_TO_DECRYPT_CERT_SIGNATURE); count++;
#endif
#ifdef X509_V_ERR_UNABLE_TO_DECRYPT_CRL_SIGNATURE
text(&entries,"V_ERR_UNABLE_TO_DECRYPT_CRL_SIGNATURE"); integer(&entries,(long long)X509_V_ERR_UNABLE_TO_DECRYPT_CRL_SIGNATURE); count++;
#endif
#ifdef X509_V_ERR_UNABLE_TO_DECODE_ISSUER_PUBLIC_KEY
text(&entries,"V_ERR_UNABLE_TO_DECODE_ISSUER_PUBLIC_KEY"); integer(&entries,(long long)X509_V_ERR_UNABLE_TO_DECODE_ISSUER_PUBLIC_KEY); count++;
#endif
#ifdef X509_V_ERR_CERT_SIGNATURE_FAILURE
text(&entries,"V_ERR_CERT_SIGNATURE_FAILURE"); integer(&entries,(long long)X509_V_ERR_CERT_SIGNATURE_FAILURE); count++;
#endif
#ifdef X509_V_ERR_CRL_SIGNATURE_FAILURE
text(&entries,"V_ERR_CRL_SIGNATURE_FAILURE"); integer(&entries,(long long)X509_V_ERR_CRL_SIGNATURE_FAILURE); count++;
#endif
#ifdef X509_V_ERR_CERT_NOT_YET_VALID
text(&entries,"V_ERR_CERT_NOT_YET_VALID"); integer(&entries,(long long)X509_V_ERR_CERT_NOT_YET_VALID); count++;
#endif
#ifdef X509_V_ERR_CERT_HAS_EXPIRED
text(&entries,"V_ERR_CERT_HAS_EXPIRED"); integer(&entries,(long long)X509_V_ERR_CERT_HAS_EXPIRED); count++;
#endif
#ifdef X509_V_ERR_CRL_NOT_YET_VALID
text(&entries,"V_ERR_CRL_NOT_YET_VALID"); integer(&entries,(long long)X509_V_ERR_CRL_NOT_YET_VALID); count++;
#endif
#ifdef X509_V_ERR_CRL_HAS_EXPIRED
text(&entries,"V_ERR_CRL_HAS_EXPIRED"); integer(&entries,(long long)X509_V_ERR_CRL_HAS_EXPIRED); count++;
#endif
#ifdef X509_V_ERR_ERROR_IN_CERT_NOT_BEFORE_FIELD
text(&entries,"V_ERR_ERROR_IN_CERT_NOT_BEFORE_FIELD"); integer(&entries,(long long)X509_V_ERR_ERROR_IN_CERT_NOT_BEFORE_FIELD); count++;
#endif
#ifdef X509_V_ERR_ERROR_IN_CERT_NOT_AFTER_FIELD
text(&entries,"V_ERR_ERROR_IN_CERT_NOT_AFTER_FIELD"); integer(&entries,(long long)X509_V_ERR_ERROR_IN_CERT_NOT_AFTER_FIELD); count++;
#endif
#ifdef X509_V_ERR_ERROR_IN_CRL_LAST_UPDATE_FIELD
text(&entries,"V_ERR_ERROR_IN_CRL_LAST_UPDATE_FIELD"); integer(&entries,(long long)X509_V_ERR_ERROR_IN_CRL_LAST_UPDATE_FIELD); count++;
#endif
#ifdef X509_V_ERR_ERROR_IN_CRL_NEXT_UPDATE_FIELD
text(&entries,"V_ERR_ERROR_IN_CRL_NEXT_UPDATE_FIELD"); integer(&entries,(long long)X509_V_ERR_ERROR_IN_CRL_NEXT_UPDATE_FIELD); count++;
#endif
#ifdef X509_V_ERR_OUT_OF_MEM
text(&entries,"V_ERR_OUT_OF_MEM"); integer(&entries,(long long)X509_V_ERR_OUT_OF_MEM); count++;
#endif
#ifdef X509_V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT
text(&entries,"V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT"); integer(&entries,(long long)X509_V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT); count++;
#endif
#ifdef X509_V_ERR_SELF_SIGNED_CERT_IN_CHAIN
text(&entries,"V_ERR_SELF_SIGNED_CERT_IN_CHAIN"); integer(&entries,(long long)X509_V_ERR_SELF_SIGNED_CERT_IN_CHAIN); count++;
#endif
#ifdef X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT_LOCALLY
text(&entries,"V_ERR_UNABLE_TO_GET_ISSUER_CERT_LOCALLY"); integer(&entries,(long long)X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT_LOCALLY); count++;
#endif
#ifdef X509_V_ERR_UNABLE_TO_VERIFY_LEAF_SIGNATURE
text(&entries,"V_ERR_UNABLE_TO_VERIFY_LEAF_SIGNATURE"); integer(&entries,(long long)X509_V_ERR_UNABLE_TO_VERIFY_LEAF_SIGNATURE); count++;
#endif
#ifdef X509_V_ERR_CERT_CHAIN_TOO_LONG
text(&entries,"V_ERR_CERT_CHAIN_TOO_LONG"); integer(&entries,(long long)X509_V_ERR_CERT_CHAIN_TOO_LONG); count++;
#endif
#ifdef X509_V_ERR_CERT_REVOKED
text(&entries,"V_ERR_CERT_REVOKED"); integer(&entries,(long long)X509_V_ERR_CERT_REVOKED); count++;
#endif
#ifdef X509_V_ERR_INVALID_CA
text(&entries,"V_ERR_INVALID_CA"); integer(&entries,(long long)X509_V_ERR_INVALID_CA); count++;
#endif
#ifdef X509_V_ERR_PATH_LENGTH_EXCEEDED
text(&entries,"V_ERR_PATH_LENGTH_EXCEEDED"); integer(&entries,(long long)X509_V_ERR_PATH_LENGTH_EXCEEDED); count++;
#endif
#ifdef X509_V_ERR_INVALID_PURPOSE
text(&entries,"V_ERR_INVALID_PURPOSE"); integer(&entries,(long long)X509_V_ERR_INVALID_PURPOSE); count++;
#endif
#ifdef X509_V_ERR_CERT_UNTRUSTED
text(&entries,"V_ERR_CERT_UNTRUSTED"); integer(&entries,(long long)X509_V_ERR_CERT_UNTRUSTED); count++;
#endif
#ifdef X509_V_ERR_CERT_REJECTED
text(&entries,"V_ERR_CERT_REJECTED"); integer(&entries,(long long)X509_V_ERR_CERT_REJECTED); count++;
#endif
#ifdef X509_V_ERR_SUBJECT_ISSUER_MISMATCH
text(&entries,"V_ERR_SUBJECT_ISSUER_MISMATCH"); integer(&entries,(long long)X509_V_ERR_SUBJECT_ISSUER_MISMATCH); count++;
#endif
#ifdef X509_V_ERR_AKID_SKID_MISMATCH
text(&entries,"V_ERR_AKID_SKID_MISMATCH"); integer(&entries,(long long)X509_V_ERR_AKID_SKID_MISMATCH); count++;
#endif
#ifdef X509_V_ERR_AKID_ISSUER_SERIAL_MISMATCH
text(&entries,"V_ERR_AKID_ISSUER_SERIAL_MISMATCH"); integer(&entries,(long long)X509_V_ERR_AKID_ISSUER_SERIAL_MISMATCH); count++;
#endif
#ifdef X509_V_ERR_KEYUSAGE_NO_CERTSIGN
text(&entries,"V_ERR_KEYUSAGE_NO_CERTSIGN"); integer(&entries,(long long)X509_V_ERR_KEYUSAGE_NO_CERTSIGN); count++;
#endif
#ifdef X509_V_ERR_UNABLE_TO_GET_CRL_ISSUER
text(&entries,"V_ERR_UNABLE_TO_GET_CRL_ISSUER"); integer(&entries,(long long)X509_V_ERR_UNABLE_TO_GET_CRL_ISSUER); count++;
#endif
#ifdef X509_V_ERR_UNHANDLED_CRITICAL_EXTENSION
text(&entries,"V_ERR_UNHANDLED_CRITICAL_EXTENSION"); integer(&entries,(long long)X509_V_ERR_UNHANDLED_CRITICAL_EXTENSION); count++;
#endif
#ifdef X509_V_ERR_KEYUSAGE_NO_CRL_SIGN
text(&entries,"V_ERR_KEYUSAGE_NO_CRL_SIGN"); integer(&entries,(long long)X509_V_ERR_KEYUSAGE_NO_CRL_SIGN); count++;
#endif
#ifdef X509_V_ERR_UNHANDLED_CRITICAL_CRL_EXTENSION
text(&entries,"V_ERR_UNHANDLED_CRITICAL_CRL_EXTENSION"); integer(&entries,(long long)X509_V_ERR_UNHANDLED_CRITICAL_CRL_EXTENSION); count++;
#endif
#ifdef X509_V_ERR_INVALID_NON_CA
text(&entries,"V_ERR_INVALID_NON_CA"); integer(&entries,(long long)X509_V_ERR_INVALID_NON_CA); count++;
#endif
#ifdef X509_V_ERR_PROXY_PATH_LENGTH_EXCEEDED
text(&entries,"V_ERR_PROXY_PATH_LENGTH_EXCEEDED"); integer(&entries,(long long)X509_V_ERR_PROXY_PATH_LENGTH_EXCEEDED); count++;
#endif
#ifdef X509_V_ERR_KEYUSAGE_NO_DIGITAL_SIGNATURE
text(&entries,"V_ERR_KEYUSAGE_NO_DIGITAL_SIGNATURE"); integer(&entries,(long long)X509_V_ERR_KEYUSAGE_NO_DIGITAL_SIGNATURE); count++;
#endif
#ifdef X509_V_ERR_PROXY_CERTIFICATES_NOT_ALLOWED
text(&entries,"V_ERR_PROXY_CERTIFICATES_NOT_ALLOWED"); integer(&entries,(long long)X509_V_ERR_PROXY_CERTIFICATES_NOT_ALLOWED); count++;
#endif
#ifdef X509_V_ERR_INVALID_EXTENSION
text(&entries,"V_ERR_INVALID_EXTENSION"); integer(&entries,(long long)X509_V_ERR_INVALID_EXTENSION); count++;
#endif
#ifdef X509_V_ERR_INVALID_POLICY_EXTENSION
text(&entries,"V_ERR_INVALID_POLICY_EXTENSION"); integer(&entries,(long long)X509_V_ERR_INVALID_POLICY_EXTENSION); count++;
#endif
#ifdef X509_V_ERR_NO_EXPLICIT_POLICY
text(&entries,"V_ERR_NO_EXPLICIT_POLICY"); integer(&entries,(long long)X509_V_ERR_NO_EXPLICIT_POLICY); count++;
#endif
#ifdef X509_V_ERR_DIFFERENT_CRL_SCOPE
text(&entries,"V_ERR_DIFFERENT_CRL_SCOPE"); integer(&entries,(long long)X509_V_ERR_DIFFERENT_CRL_SCOPE); count++;
#endif
#ifdef X509_V_ERR_UNSUPPORTED_EXTENSION_FEATURE
text(&entries,"V_ERR_UNSUPPORTED_EXTENSION_FEATURE"); integer(&entries,(long long)X509_V_ERR_UNSUPPORTED_EXTENSION_FEATURE); count++;
#endif
#ifdef X509_V_ERR_UNNESTED_RESOURCE
text(&entries,"V_ERR_UNNESTED_RESOURCE"); integer(&entries,(long long)X509_V_ERR_UNNESTED_RESOURCE); count++;
#endif
#ifdef X509_V_ERR_PERMITTED_VIOLATION
text(&entries,"V_ERR_PERMITTED_VIOLATION"); integer(&entries,(long long)X509_V_ERR_PERMITTED_VIOLATION); count++;
#endif
#ifdef X509_V_ERR_EXCLUDED_VIOLATION
text(&entries,"V_ERR_EXCLUDED_VIOLATION"); integer(&entries,(long long)X509_V_ERR_EXCLUDED_VIOLATION); count++;
#endif
#ifdef X509_V_ERR_SUBTREE_MINMAX
text(&entries,"V_ERR_SUBTREE_MINMAX"); integer(&entries,(long long)X509_V_ERR_SUBTREE_MINMAX); count++;
#endif
#ifdef X509_V_ERR_APPLICATION_VERIFICATION
text(&entries,"V_ERR_APPLICATION_VERIFICATION"); integer(&entries,(long long)X509_V_ERR_APPLICATION_VERIFICATION); count++;
#endif
#ifdef X509_V_ERR_UNSUPPORTED_CONSTRAINT_TYPE
text(&entries,"V_ERR_UNSUPPORTED_CONSTRAINT_TYPE"); integer(&entries,(long long)X509_V_ERR_UNSUPPORTED_CONSTRAINT_TYPE); count++;
#endif
#ifdef X509_V_ERR_UNSUPPORTED_CONSTRAINT_SYNTAX
text(&entries,"V_ERR_UNSUPPORTED_CONSTRAINT_SYNTAX"); integer(&entries,(long long)X509_V_ERR_UNSUPPORTED_CONSTRAINT_SYNTAX); count++;
#endif
#ifdef X509_V_ERR_UNSUPPORTED_NAME_SYNTAX
text(&entries,"V_ERR_UNSUPPORTED_NAME_SYNTAX"); integer(&entries,(long long)X509_V_ERR_UNSUPPORTED_NAME_SYNTAX); count++;
#endif
#ifdef X509_V_ERR_CRL_PATH_VALIDATION_ERROR
text(&entries,"V_ERR_CRL_PATH_VALIDATION_ERROR"); integer(&entries,(long long)X509_V_ERR_CRL_PATH_VALIDATION_ERROR); count++;
#endif
#ifdef X509_V_ERR_PATH_LOOP
text(&entries,"V_ERR_PATH_LOOP"); integer(&entries,(long long)X509_V_ERR_PATH_LOOP); count++;
#endif
#ifdef X509_V_ERR_SUITE_B_INVALID_VERSION
text(&entries,"V_ERR_SUITE_B_INVALID_VERSION"); integer(&entries,(long long)X509_V_ERR_SUITE_B_INVALID_VERSION); count++;
#endif
#ifdef X509_V_ERR_SUITE_B_INVALID_ALGORITHM
text(&entries,"V_ERR_SUITE_B_INVALID_ALGORITHM"); integer(&entries,(long long)X509_V_ERR_SUITE_B_INVALID_ALGORITHM); count++;
#endif
#ifdef X509_V_ERR_SUITE_B_INVALID_CURVE
text(&entries,"V_ERR_SUITE_B_INVALID_CURVE"); integer(&entries,(long long)X509_V_ERR_SUITE_B_INVALID_CURVE); count++;
#endif
#ifdef X509_V_ERR_SUITE_B_INVALID_SIGNATURE_ALGORITHM
text(&entries,"V_ERR_SUITE_B_INVALID_SIGNATURE_ALGORITHM"); integer(&entries,(long long)X509_V_ERR_SUITE_B_INVALID_SIGNATURE_ALGORITHM); count++;
#endif
#ifdef X509_V_ERR_SUITE_B_LOS_NOT_ALLOWED
text(&entries,"V_ERR_SUITE_B_LOS_NOT_ALLOWED"); integer(&entries,(long long)X509_V_ERR_SUITE_B_LOS_NOT_ALLOWED); count++;
#endif
#ifdef X509_V_ERR_SUITE_B_CANNOT_SIGN_P_384_WITH_P_256
text(&entries,"V_ERR_SUITE_B_CANNOT_SIGN_P_384_WITH_P_256"); integer(&entries,(long long)X509_V_ERR_SUITE_B_CANNOT_SIGN_P_384_WITH_P_256); count++;
#endif
#ifdef X509_V_ERR_HOSTNAME_MISMATCH
text(&entries,"V_ERR_HOSTNAME_MISMATCH"); integer(&entries,(long long)X509_V_ERR_HOSTNAME_MISMATCH); count++;
#endif
#ifdef X509_V_ERR_EMAIL_MISMATCH
text(&entries,"V_ERR_EMAIL_MISMATCH"); integer(&entries,(long long)X509_V_ERR_EMAIL_MISMATCH); count++;
#endif
#ifdef X509_V_ERR_IP_ADDRESS_MISMATCH
text(&entries,"V_ERR_IP_ADDRESS_MISMATCH"); integer(&entries,(long long)X509_V_ERR_IP_ADDRESS_MISMATCH); count++;
#endif
#ifdef X509_V_ERR_DANE_NO_MATCH
text(&entries,"V_ERR_DANE_NO_MATCH"); integer(&entries,(long long)X509_V_ERR_DANE_NO_MATCH); count++;
#endif
#ifdef X509_V_ERR_EE_KEY_TOO_SMALL
text(&entries,"V_ERR_EE_KEY_TOO_SMALL"); integer(&entries,(long long)X509_V_ERR_EE_KEY_TOO_SMALL); count++;
#endif
#ifdef X509_V_ERR_CA_KEY_TOO_SMALL
text(&entries,"V_ERR_CA_KEY_TOO_SMALL"); integer(&entries,(long long)X509_V_ERR_CA_KEY_TOO_SMALL); count++;
#endif
#ifdef X509_V_ERR_CA_MD_TOO_WEAK
text(&entries,"V_ERR_CA_MD_TOO_WEAK"); integer(&entries,(long long)X509_V_ERR_CA_MD_TOO_WEAK); count++;
#endif
#ifdef X509_V_ERR_INVALID_CALL
text(&entries,"V_ERR_INVALID_CALL"); integer(&entries,(long long)X509_V_ERR_INVALID_CALL); count++;
#endif
#ifdef X509_V_ERR_STORE_LOOKUP
text(&entries,"V_ERR_STORE_LOOKUP"); integer(&entries,(long long)X509_V_ERR_STORE_LOOKUP); count++;
#endif
#ifdef X509_V_ERR_NO_VALID_SCTS
text(&entries,"V_ERR_NO_VALID_SCTS"); integer(&entries,(long long)X509_V_ERR_NO_VALID_SCTS); count++;
#endif
#ifdef X509_V_ERR_PROXY_SUBJECT_NAME_VIOLATION
text(&entries,"V_ERR_PROXY_SUBJECT_NAME_VIOLATION"); integer(&entries,(long long)X509_V_ERR_PROXY_SUBJECT_NAME_VIOLATION); count++;
#endif
#ifdef X509_V_ERR_OCSP_VERIFY_NEEDED
text(&entries,"V_ERR_OCSP_VERIFY_NEEDED"); integer(&entries,(long long)X509_V_ERR_OCSP_VERIFY_NEEDED); count++;
#endif
#ifdef X509_V_ERR_OCSP_VERIFY_FAILED
text(&entries,"V_ERR_OCSP_VERIFY_FAILED"); integer(&entries,(long long)X509_V_ERR_OCSP_VERIFY_FAILED); count++;
#endif
#ifdef X509_V_ERR_OCSP_CERT_UNKNOWN
text(&entries,"V_ERR_OCSP_CERT_UNKNOWN"); integer(&entries,(long long)X509_V_ERR_OCSP_CERT_UNKNOWN); count++;
#endif
#ifdef X509_V_FLAG_USE_CHECK_TIME
text(&entries,"V_FLAG_USE_CHECK_TIME"); integer(&entries,(long long)X509_V_FLAG_USE_CHECK_TIME); count++;
#endif
#ifdef X509_V_FLAG_CRL_CHECK
text(&entries,"V_FLAG_CRL_CHECK"); integer(&entries,(long long)X509_V_FLAG_CRL_CHECK); count++;
#endif
#ifdef X509_V_FLAG_CRL_CHECK_ALL
text(&entries,"V_FLAG_CRL_CHECK_ALL"); integer(&entries,(long long)X509_V_FLAG_CRL_CHECK_ALL); count++;
#endif
#ifdef X509_V_FLAG_IGNORE_CRITICAL
text(&entries,"V_FLAG_IGNORE_CRITICAL"); integer(&entries,(long long)X509_V_FLAG_IGNORE_CRITICAL); count++;
#endif
#ifdef X509_V_FLAG_X509_STRICT
text(&entries,"V_FLAG_X509_STRICT"); integer(&entries,(long long)X509_V_FLAG_X509_STRICT); count++;
#endif
#ifdef X509_V_FLAG_ALLOW_PROXY_CERTS
text(&entries,"V_FLAG_ALLOW_PROXY_CERTS"); integer(&entries,(long long)X509_V_FLAG_ALLOW_PROXY_CERTS); count++;
#endif
#ifdef X509_V_FLAG_POLICY_CHECK
text(&entries,"V_FLAG_POLICY_CHECK"); integer(&entries,(long long)X509_V_FLAG_POLICY_CHECK); count++;
#endif
#ifdef X509_V_FLAG_EXPLICIT_POLICY
text(&entries,"V_FLAG_EXPLICIT_POLICY"); integer(&entries,(long long)X509_V_FLAG_EXPLICIT_POLICY); count++;
#endif
#ifdef X509_V_FLAG_INHIBIT_ANY
text(&entries,"V_FLAG_INHIBIT_ANY"); integer(&entries,(long long)X509_V_FLAG_INHIBIT_ANY); count++;
#endif
#ifdef X509_V_FLAG_INHIBIT_MAP
text(&entries,"V_FLAG_INHIBIT_MAP"); integer(&entries,(long long)X509_V_FLAG_INHIBIT_MAP); count++;
#endif
#ifdef X509_V_FLAG_NOTIFY_POLICY
text(&entries,"V_FLAG_NOTIFY_POLICY"); integer(&entries,(long long)X509_V_FLAG_NOTIFY_POLICY); count++;
#endif
#ifdef X509_V_FLAG_EXTENDED_CRL_SUPPORT
text(&entries,"V_FLAG_EXTENDED_CRL_SUPPORT"); integer(&entries,(long long)X509_V_FLAG_EXTENDED_CRL_SUPPORT); count++;
#endif
#ifdef X509_V_FLAG_USE_DELTAS
text(&entries,"V_FLAG_USE_DELTAS"); integer(&entries,(long long)X509_V_FLAG_USE_DELTAS); count++;
#endif
#ifdef X509_V_FLAG_CHECK_SS_SIGNATURE
text(&entries,"V_FLAG_CHECK_SS_SIGNATURE"); integer(&entries,(long long)X509_V_FLAG_CHECK_SS_SIGNATURE); count++;
#endif
#ifdef X509_V_FLAG_TRUSTED_FIRST
text(&entries,"V_FLAG_TRUSTED_FIRST"); integer(&entries,(long long)X509_V_FLAG_TRUSTED_FIRST); count++;
#endif
#ifdef X509_V_FLAG_SUITEB_128_LOS_ONLY
text(&entries,"V_FLAG_SUITEB_128_LOS_ONLY"); integer(&entries,(long long)X509_V_FLAG_SUITEB_128_LOS_ONLY); count++;
#endif
#ifdef X509_V_FLAG_SUITEB_192_LOS
text(&entries,"V_FLAG_SUITEB_192_LOS"); integer(&entries,(long long)X509_V_FLAG_SUITEB_192_LOS); count++;
#endif
#ifdef X509_V_FLAG_SUITEB_128_LOS
text(&entries,"V_FLAG_SUITEB_128_LOS"); integer(&entries,(long long)X509_V_FLAG_SUITEB_128_LOS); count++;
#endif
#ifdef X509_V_FLAG_PARTIAL_CHAIN
text(&entries,"V_FLAG_PARTIAL_CHAIN"); integer(&entries,(long long)X509_V_FLAG_PARTIAL_CHAIN); count++;
#endif
#ifdef X509_V_FLAG_NO_ALT_CHAINS
text(&entries,"V_FLAG_NO_ALT_CHAINS"); integer(&entries,(long long)X509_V_FLAG_NO_ALT_CHAINS); count++;
#endif
#ifdef X509_V_FLAG_NO_CHECK_TIME
text(&entries,"V_FLAG_NO_CHECK_TIME"); integer(&entries,(long long)X509_V_FLAG_NO_CHECK_TIME); count++;
#endif
#ifdef X509_PURPOSE_SSL_CLIENT
text(&entries,"PURPOSE_SSL_CLIENT"); integer(&entries,(long long)X509_PURPOSE_SSL_CLIENT); count++;
#endif
#ifdef X509_PURPOSE_SSL_SERVER
text(&entries,"PURPOSE_SSL_SERVER"); integer(&entries,(long long)X509_PURPOSE_SSL_SERVER); count++;
#endif
#ifdef X509_PURPOSE_NS_SSL_SERVER
text(&entries,"PURPOSE_NS_SSL_SERVER"); integer(&entries,(long long)X509_PURPOSE_NS_SSL_SERVER); count++;
#endif
#ifdef X509_PURPOSE_SMIME_SIGN
text(&entries,"PURPOSE_SMIME_SIGN"); integer(&entries,(long long)X509_PURPOSE_SMIME_SIGN); count++;
#endif
#ifdef X509_PURPOSE_SMIME_ENCRYPT
text(&entries,"PURPOSE_SMIME_ENCRYPT"); integer(&entries,(long long)X509_PURPOSE_SMIME_ENCRYPT); count++;
#endif
#ifdef X509_PURPOSE_CRL_SIGN
text(&entries,"PURPOSE_CRL_SIGN"); integer(&entries,(long long)X509_PURPOSE_CRL_SIGN); count++;
#endif
#ifdef X509_PURPOSE_ANY
text(&entries,"PURPOSE_ANY"); integer(&entries,(long long)X509_PURPOSE_ANY); count++;
#endif
#ifdef X509_PURPOSE_OCSP_HELPER
text(&entries,"PURPOSE_OCSP_HELPER"); integer(&entries,(long long)X509_PURPOSE_OCSP_HELPER); count++;
#endif
#ifdef X509_PURPOSE_TIMESTAMP_SIGN
text(&entries,"PURPOSE_TIMESTAMP_SIGN"); integer(&entries,(long long)X509_PURPOSE_TIMESTAMP_SIGN); count++;
#endif
#ifdef X509_TRUST_COMPAT
text(&entries,"TRUST_COMPAT"); integer(&entries,(long long)X509_TRUST_COMPAT); count++;
#endif
#ifdef X509_TRUST_SSL_CLIENT
text(&entries,"TRUST_SSL_CLIENT"); integer(&entries,(long long)X509_TRUST_SSL_CLIENT); count++;
#endif
#ifdef X509_TRUST_SSL_SERVER
text(&entries,"TRUST_SSL_SERVER"); integer(&entries,(long long)X509_TRUST_SSL_SERVER); count++;
#endif
#ifdef X509_TRUST_EMAIL
text(&entries,"TRUST_EMAIL"); integer(&entries,(long long)X509_TRUST_EMAIL); count++;
#endif
#ifdef X509_TRUST_OBJECT_SIGN
text(&entries,"TRUST_OBJECT_SIGN"); integer(&entries,(long long)X509_TRUST_OBJECT_SIGN); count++;
#endif
#ifdef X509_TRUST_OCSP_SIGN
text(&entries,"TRUST_OCSP_SIGN"); integer(&entries,(long long)X509_TRUST_OCSP_SIGN); count++;
#endif
#ifdef X509_TRUST_OCSP_REQUEST
text(&entries,"TRUST_OCSP_REQUEST"); integer(&entries,(long long)X509_TRUST_OCSP_REQUEST); count++;
#endif
#ifdef X509_TRUST_TSA
text(&entries,"TRUST_TSA"); integer(&entries,(long long)X509_TRUST_TSA); count++;
#endif
byte(out,'m'); number(out,count); put(out,entries.p,entries.len); free(entries.p);
}

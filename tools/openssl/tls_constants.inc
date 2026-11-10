/* The linked provider supplies its own SSL constants. */
static void tls_constants(buffer *out) {
buffer entries={0}; unsigned count=0;
#ifdef SSL_VERIFY_NONE
text(&entries,"VERIFY_NONE"); integer(&entries,(long long)SSL_VERIFY_NONE); count++;
#endif
#ifdef SSL_VERIFY_PEER
text(&entries,"VERIFY_PEER"); integer(&entries,(long long)SSL_VERIFY_PEER); count++;
#endif
#ifdef SSL_VERIFY_FAIL_IF_NO_PEER_CERT
text(&entries,"VERIFY_FAIL_IF_NO_PEER_CERT"); integer(&entries,(long long)SSL_VERIFY_FAIL_IF_NO_PEER_CERT); count++;
#endif
#ifdef SSL_VERIFY_CLIENT_ONCE
text(&entries,"VERIFY_CLIENT_ONCE"); integer(&entries,(long long)SSL_VERIFY_CLIENT_ONCE); count++;
#endif
#ifdef SSL_OP_ALL
text(&entries,"OP_ALL"); integer(&entries,(long long)SSL_OP_ALL); count++;
#endif
#ifdef SSL_OP_CLEANSE_PLAINTEXT
text(&entries,"OP_CLEANSE_PLAINTEXT"); integer(&entries,(long long)SSL_OP_CLEANSE_PLAINTEXT); count++;
#endif
#ifdef SSL_OP_LEGACY_SERVER_CONNECT
text(&entries,"OP_LEGACY_SERVER_CONNECT"); integer(&entries,(long long)SSL_OP_LEGACY_SERVER_CONNECT); count++;
#endif
#ifdef SSL_OP_ENABLE_KTLS
text(&entries,"OP_ENABLE_KTLS"); integer(&entries,(long long)SSL_OP_ENABLE_KTLS); count++;
#endif
#ifdef SSL_OP_TLSEXT_PADDING
text(&entries,"OP_TLSEXT_PADDING"); integer(&entries,(long long)SSL_OP_TLSEXT_PADDING); count++;
#endif
#ifdef SSL_OP_SAFARI_ECDHE_ECDSA_BUG
text(&entries,"OP_SAFARI_ECDHE_ECDSA_BUG"); integer(&entries,(long long)SSL_OP_SAFARI_ECDHE_ECDSA_BUG); count++;
#endif
#ifdef SSL_OP_IGNORE_UNEXPECTED_EOF
text(&entries,"OP_IGNORE_UNEXPECTED_EOF"); integer(&entries,(long long)SSL_OP_IGNORE_UNEXPECTED_EOF); count++;
#endif
#ifdef SSL_OP_ALLOW_CLIENT_RENEGOTIATION
text(&entries,"OP_ALLOW_CLIENT_RENEGOTIATION"); integer(&entries,(long long)SSL_OP_ALLOW_CLIENT_RENEGOTIATION); count++;
#endif
#ifdef SSL_OP_DISABLE_TLSEXT_CA_NAMES
text(&entries,"OP_DISABLE_TLSEXT_CA_NAMES"); integer(&entries,(long long)SSL_OP_DISABLE_TLSEXT_CA_NAMES); count++;
#endif
#ifdef SSL_OP_ALLOW_NO_DHE_KEX
text(&entries,"OP_ALLOW_NO_DHE_KEX"); integer(&entries,(long long)SSL_OP_ALLOW_NO_DHE_KEX); count++;
#endif
#ifdef SSL_OP_DONT_INSERT_EMPTY_FRAGMENTS
text(&entries,"OP_DONT_INSERT_EMPTY_FRAGMENTS"); integer(&entries,(long long)SSL_OP_DONT_INSERT_EMPTY_FRAGMENTS); count++;
#endif
#ifdef SSL_OP_NO_TICKET
text(&entries,"OP_NO_TICKET"); integer(&entries,(long long)SSL_OP_NO_TICKET); count++;
#endif
#ifdef SSL_OP_NO_SESSION_RESUMPTION_ON_RENEGOTIATION
text(&entries,"OP_NO_SESSION_RESUMPTION_ON_RENEGOTIATION"); integer(&entries,(long long)SSL_OP_NO_SESSION_RESUMPTION_ON_RENEGOTIATION); count++;
#endif
#ifdef SSL_OP_NO_COMPRESSION
text(&entries,"OP_NO_COMPRESSION"); integer(&entries,(long long)SSL_OP_NO_COMPRESSION); count++;
#endif
#ifdef SSL_OP_ALLOW_UNSAFE_LEGACY_RENEGOTIATION
text(&entries,"OP_ALLOW_UNSAFE_LEGACY_RENEGOTIATION"); integer(&entries,(long long)SSL_OP_ALLOW_UNSAFE_LEGACY_RENEGOTIATION); count++;
#endif
#ifdef SSL_OP_NO_ENCRYPT_THEN_MAC
text(&entries,"OP_NO_ENCRYPT_THEN_MAC"); integer(&entries,(long long)SSL_OP_NO_ENCRYPT_THEN_MAC); count++;
#endif
#ifdef SSL_OP_ENABLE_MIDDLEBOX_COMPAT
text(&entries,"OP_ENABLE_MIDDLEBOX_COMPAT"); integer(&entries,(long long)SSL_OP_ENABLE_MIDDLEBOX_COMPAT); count++;
#endif
#ifdef SSL_OP_PRIORITIZE_CHACHA
text(&entries,"OP_PRIORITIZE_CHACHA"); integer(&entries,(long long)SSL_OP_PRIORITIZE_CHACHA); count++;
#endif
#ifdef SSL_OP_NO_ANTI_REPLAY
text(&entries,"OP_NO_ANTI_REPLAY"); integer(&entries,(long long)SSL_OP_NO_ANTI_REPLAY); count++;
#endif
#ifdef SSL_OP_NO_SSLv3
text(&entries,"OP_NO_SSLv3"); integer(&entries,(long long)SSL_OP_NO_SSLv3); count++;
#endif
#ifdef SSL_OP_NO_TLSv1
text(&entries,"OP_NO_TLSv1"); integer(&entries,(long long)SSL_OP_NO_TLSv1); count++;
#endif
#ifdef SSL_OP_NO_TLSv1_1
text(&entries,"OP_NO_TLSv1_1"); integer(&entries,(long long)SSL_OP_NO_TLSv1_1); count++;
#endif
#ifdef SSL_OP_NO_TLSv1_2
text(&entries,"OP_NO_TLSv1_2"); integer(&entries,(long long)SSL_OP_NO_TLSv1_2); count++;
#endif
#ifdef SSL_OP_NO_TLSv1_3
text(&entries,"OP_NO_TLSv1_3"); integer(&entries,(long long)SSL_OP_NO_TLSv1_3); count++;
#endif
#ifdef SSL_OP_CIPHER_SERVER_PREFERENCE
text(&entries,"OP_CIPHER_SERVER_PREFERENCE"); integer(&entries,(long long)SSL_OP_CIPHER_SERVER_PREFERENCE); count++;
#endif
#ifdef SSL_OP_TLS_ROLLBACK_BUG
text(&entries,"OP_TLS_ROLLBACK_BUG"); integer(&entries,(long long)SSL_OP_TLS_ROLLBACK_BUG); count++;
#endif
#ifdef SSL_OP_NO_RENEGOTIATION
text(&entries,"OP_NO_RENEGOTIATION"); integer(&entries,(long long)SSL_OP_NO_RENEGOTIATION); count++;
#endif
#ifdef SSL_OP_CRYPTOPRO_TLSEXT_BUG
text(&entries,"OP_CRYPTOPRO_TLSEXT_BUG"); integer(&entries,(long long)SSL_OP_CRYPTOPRO_TLSEXT_BUG); count++;
#endif
#ifdef SSL_OP_NO_QUERY_MTU
text(&entries,"OP_NO_QUERY_MTU"); integer(&entries,(long long)SSL_OP_NO_QUERY_MTU); count++;
#endif
#ifdef SSL_OP_COOKIE_EXCHANGE
text(&entries,"OP_COOKIE_EXCHANGE"); integer(&entries,(long long)SSL_OP_COOKIE_EXCHANGE); count++;
#endif
#ifdef SSL_OP_CISCO_ANYCONNECT
text(&entries,"OP_CISCO_ANYCONNECT"); integer(&entries,(long long)SSL_OP_CISCO_ANYCONNECT); count++;
#endif
#ifdef SSL_OP_MICROSOFT_SESS_ID_BUG
text(&entries,"OP_MICROSOFT_SESS_ID_BUG"); integer(&entries,(long long)SSL_OP_MICROSOFT_SESS_ID_BUG); count++;
#endif
#ifdef SSL_OP_NETSCAPE_CHALLENGE_BUG
text(&entries,"OP_NETSCAPE_CHALLENGE_BUG"); integer(&entries,(long long)SSL_OP_NETSCAPE_CHALLENGE_BUG); count++;
#endif
#ifdef SSL_OP_NETSCAPE_REUSE_CIPHER_CHANGE_BUG
text(&entries,"OP_NETSCAPE_REUSE_CIPHER_CHANGE_BUG"); integer(&entries,(long long)SSL_OP_NETSCAPE_REUSE_CIPHER_CHANGE_BUG); count++;
#endif
#ifdef SSL_OP_SSLREF2_REUSE_CERT_TYPE_BUG
text(&entries,"OP_SSLREF2_REUSE_CERT_TYPE_BUG"); integer(&entries,(long long)SSL_OP_SSLREF2_REUSE_CERT_TYPE_BUG); count++;
#endif
#ifdef SSL_OP_MICROSOFT_BIG_SSLV3_BUFFER
text(&entries,"OP_MICROSOFT_BIG_SSLV3_BUFFER"); integer(&entries,(long long)SSL_OP_MICROSOFT_BIG_SSLV3_BUFFER); count++;
#endif
#ifdef SSL_OP_MSIE_SSLV2_RSA_PADDING
text(&entries,"OP_MSIE_SSLV2_RSA_PADDING"); integer(&entries,(long long)SSL_OP_MSIE_SSLV2_RSA_PADDING); count++;
#endif
#ifdef SSL_OP_SSLEAY_080_CLIENT_DH_BUG
text(&entries,"OP_SSLEAY_080_CLIENT_DH_BUG"); integer(&entries,(long long)SSL_OP_SSLEAY_080_CLIENT_DH_BUG); count++;
#endif
#ifdef SSL_OP_TLS_D5_BUG
text(&entries,"OP_TLS_D5_BUG"); integer(&entries,(long long)SSL_OP_TLS_D5_BUG); count++;
#endif
#ifdef SSL_OP_TLS_BLOCK_PADDING_BUG
text(&entries,"OP_TLS_BLOCK_PADDING_BUG"); integer(&entries,(long long)SSL_OP_TLS_BLOCK_PADDING_BUG); count++;
#endif
#ifdef SSL_OP_SINGLE_ECDH_USE
text(&entries,"OP_SINGLE_ECDH_USE"); integer(&entries,(long long)SSL_OP_SINGLE_ECDH_USE); count++;
#endif
#ifdef SSL_OP_SINGLE_DH_USE
text(&entries,"OP_SINGLE_DH_USE"); integer(&entries,(long long)SSL_OP_SINGLE_DH_USE); count++;
#endif
#ifdef SSL_OP_EPHEMERAL_RSA
text(&entries,"OP_EPHEMERAL_RSA"); integer(&entries,(long long)SSL_OP_EPHEMERAL_RSA); count++;
#endif
#ifdef SSL_OP_NO_SSLv2
text(&entries,"OP_NO_SSLv2"); integer(&entries,(long long)SSL_OP_NO_SSLv2); count++;
#endif
#ifdef SSL_OP_PKCS1_CHECK_1
text(&entries,"OP_PKCS1_CHECK_1"); integer(&entries,(long long)SSL_OP_PKCS1_CHECK_1); count++;
#endif
#ifdef SSL_OP_PKCS1_CHECK_2
text(&entries,"OP_PKCS1_CHECK_2"); integer(&entries,(long long)SSL_OP_PKCS1_CHECK_2); count++;
#endif
#ifdef SSL_OP_NETSCAPE_CA_DN_BUG
text(&entries,"OP_NETSCAPE_CA_DN_BUG"); integer(&entries,(long long)SSL_OP_NETSCAPE_CA_DN_BUG); count++;
#endif
#ifdef SSL_OP_NETSCAPE_DEMO_CIPHER_CHANGE_BUG
text(&entries,"OP_NETSCAPE_DEMO_CIPHER_CHANGE_BUG"); integer(&entries,(long long)SSL_OP_NETSCAPE_DEMO_CIPHER_CHANGE_BUG); count++;
#endif
#ifdef SSL2_VERSION
text(&entries,"SSL2_VERSION"); integer(&entries,(long long)SSL2_VERSION); count++;
#endif
#ifdef SSL3_VERSION
text(&entries,"SSL3_VERSION"); integer(&entries,(long long)SSL3_VERSION); count++;
#endif
#ifdef TLS1_VERSION
text(&entries,"TLS1_VERSION"); integer(&entries,(long long)TLS1_VERSION); count++;
#endif
#ifdef TLS1_1_VERSION
text(&entries,"TLS1_1_VERSION"); integer(&entries,(long long)TLS1_1_VERSION); count++;
#endif
#ifdef TLS1_2_VERSION
text(&entries,"TLS1_2_VERSION"); integer(&entries,(long long)TLS1_2_VERSION); count++;
#endif
#ifdef TLS1_3_VERSION
text(&entries,"TLS1_3_VERSION"); integer(&entries,(long long)TLS1_3_VERSION); count++;
#endif
#ifdef SSL_SESS_CACHE_OFF
text(&entries,"SESSION_CACHE_OFF"); integer(&entries,(long long)SSL_SESS_CACHE_OFF); count++;
#endif
#ifdef SSL_SESS_CACHE_CLIENT
text(&entries,"SESSION_CACHE_CLIENT"); integer(&entries,(long long)SSL_SESS_CACHE_CLIENT); count++;
#endif
#ifdef SSL_SESS_CACHE_SERVER
text(&entries,"SESSION_CACHE_SERVER"); integer(&entries,(long long)SSL_SESS_CACHE_SERVER); count++;
#endif
#ifdef SSL_SESS_CACHE_BOTH
text(&entries,"SESSION_CACHE_BOTH"); integer(&entries,(long long)SSL_SESS_CACHE_BOTH); count++;
#endif
#ifdef SSL_SESS_CACHE_NO_AUTO_CLEAR
text(&entries,"SESSION_CACHE_NO_AUTO_CLEAR"); integer(&entries,(long long)SSL_SESS_CACHE_NO_AUTO_CLEAR); count++;
#endif
#ifdef SSL_SESS_CACHE_NO_INTERNAL_LOOKUP
text(&entries,"SESSION_CACHE_NO_INTERNAL_LOOKUP"); integer(&entries,(long long)SSL_SESS_CACHE_NO_INTERNAL_LOOKUP); count++;
#endif
#ifdef SSL_SESS_CACHE_NO_INTERNAL_STORE
text(&entries,"SESSION_CACHE_NO_INTERNAL_STORE"); integer(&entries,(long long)SSL_SESS_CACHE_NO_INTERNAL_STORE); count++;
#endif
#ifdef SSL_SESS_CACHE_NO_INTERNAL
text(&entries,"SESSION_CACHE_NO_INTERNAL"); integer(&entries,(long long)SSL_SESS_CACHE_NO_INTERNAL); count++;
#endif
byte(out,'m'); number(out,count); put(out,entries.p,entries.len); free(entries.p);
}

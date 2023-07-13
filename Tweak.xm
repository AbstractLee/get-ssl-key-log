#import <dlfcn.h>
#import "substrate.h"

static NSString *logPath = @"/var/mobile/Library/Preferences/com.apple.boringssl.keylog";

static void call_back(const void *ssl, const char *line) {
    // Log
    NSLog(@"[xlog] key_file:%s", line);
	if (line != NULL) {
        NSMutableString *lineString = [NSMutableString stringWithUTF8String:line];
        if (lineString.length > 0) {
            [lineString appendString:@"\n"];

            NSLog(@"[xlog] Writing to: %@", logPath);
            if (![NSFileManager.defaultManager fileExistsAtPath:logPath]) {
                [NSData.data writeToFile:logPath atomically:YES];
            } 

            NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:logPath];
            [handle truncateFileAtOffset:handle.seekToEndOfFile];
            [handle writeData:[lineString dataUsingEncoding:NSUTF8StringEncoding]];
            [handle closeFile];
        }
    }
}

// iOS16.5
//  __ZN4bssl14ssl_log_secretEPK6ssl_stPKcNS_4SpanIKhEE:        // bssl::ssl_log_secret(ssl_st const*, char const*, bssl::Span<unsigned char const>)
// 0x00000001aed744e0 FF8301D1               sub        sp, sp, #0x60 ; Begin of try block, CODE XREF=__ZN4bssl25tls13_derive_early_secretEPNS_13SSL_HANDSHAKEE+120, __ZN4bssl30tls13_derive_handshake_secretsEPNS_13SSL_HANDSHAKEE+84, __ZN4bssl30tls13_derive_handshake_secretsEPNS_13SSL_HANDSHAKEE+164, __ZN4bssl32tls13_derive_application_secretsEPNS_13SSL_HANDSHAKEE+104, __ZN4bssl32tls13_derive_application_secretsEPNS_13SSL_HANDSHAKEE+172, __ZN4bssl32tls13_derive_application_secretsEPNS_13SSL_HANDSHAKEE+256, __ZN4bssl17ssl_send_finishedEPNS_13SSL_HANDSHAKEE+120
// 0x00000001aed744e4 F65703A9               stp        x22, x21, [sp, #0x30]
// 0x00000001aed744e8 F44F04A9               stp        x20, x19, [sp, #0x40]
// 0x00000001aed744ec FD7B05A9               stp        fp, lr, [sp, #0x50]
// 0x00000001aed744f0 FD430191               add        fp, sp, #0x50
// 0x00000001aed744f4 083C40F9               ldr        x8, [x0, #0x78] x8 = SSL_CTX
// 0x00000001aed744f8 088141F9               ldr        x8, [x8, #0x300] call_back offset = 0x300
// 0x00000001aed744fc 480800B4               cbz        x8, loc_1aed74604

static void* (*original_SSL_ctx_new)(void *method);
static void* replaced_SSL_ctx_new(void *method) {
    NSLog(@"[xlog] Entering SSL_CTX_new()");
	void *ssl_ctx = original_SSL_ctx_new(method);
	intptr_t ctx_char = (intptr_t)ssl_ctx;
    intptr_t **keylog_callback = (intptr_t **)(ctx_char + 0x300); // iOS16.5
    *keylog_callback = (intptr_t *)call_back;

    return ssl_ctx;
}

%ctor {
	void* boringssl_handle = dlopen("/usr/lib/libboringssl.dylib", RTLD_NOW);
	void* SSL_ctx_new = dlsym(boringssl_handle, "SSL_CTX_new");
	if (SSL_ctx_new){
		NSLog(@"[xlog] Hooking SSL_CTX_new()...");
		MSHookFunction((void *) SSL_ctx_new, (void *) replaced_SSL_ctx_new,  (void **) &original_SSL_ctx_new);
	}
}
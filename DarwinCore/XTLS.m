//
//  XTLS.m
//  DarwinCore
//
//  Created by yarshure on 2017/9/15.
//  Copyright © 2017年 Kong XiangBo. All rights reserved.
//

#import "XTLS.h"

@implementation XTLS
- (void)connect {
    _aps = [NSString stringWithFormat:@"aps%ld", (long)_app];
    _apsDevelopment = [NSString stringWithFormat:@"aps_development%ld", (long)_app];
    _certificatePath = _production?[[NSBundle mainBundle] pathForResource:_aps ofType:@"cer"]:[[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:_apsDevelopment, (long)_app] ofType:@"cer"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:_certificatePath]) {
        return;
    }
    
    const char *hostName = _production?"gateway.push.apple.com":"gateway.sandbox.push.apple.com";
    
    // Create certificate.
    NSData *certificateData = [NSData dataWithContentsOfFile:_certificatePath];
    
    _certificateRef = SecCertificateCreateWithData(kCFAllocatorDefault, (CFDataRef)certificateData);
    if (_certificateRef == NULL) {
       
        return;
    }
    
    // Define result variable.
    OSStatus result;
    
    // Establish connection to server.
    PeerSpec peer;
    result = MakeServerConnection(hostName, 2195,1, &_socket, &peer);// NSLog(@"MakeServerConnection(): %d", result);
    
    // Create new SSL context.
    _contextRef = SSLCreateContext(kCFAllocatorDefault, kSSLClientSide, kSSLStreamType);
    //SSLNewContext(false, &_contextRef);// NSLog(@"SSLNewContext(): %d", result);
    
    // Set callback functions for SSL context.
    result = SSLSetIOFuncs(_contextRef, SocketRead, SocketWrite);// NSLog(@"SSLSetIOFuncs(): %d", result);
    
    // Set SSL context connection.
    result = SSLSetConnection(_contextRef, (SSLConnectionRef*)&_socket);// NSLog(@"SSLSetConnection(): %d", result);
    //??
    // Set server domain name.
    result = SSLSetPeerDomainName(_contextRef, hostName, 30);// NSLog(@"SSLSetPeerDomainName(): %d", result);
    
    // Open keychain.
    result = SecKeychainCopyDefault(&_keychainRef);// NSLog(@"SecKeychainOpen(): %d", result);
    
    // Create identity.
    result = SecIdentityCreateWithCertificate(_keychainRef, _certificateRef, &_identityRef);// NSLog(@"SecIdentityCreateWithCertificate(): %d", result);
    
    // Set client certificate.
    CFArrayRef certificates = CFArrayCreate(NULL, (const void **)&_identityRef, 1, NULL);
    result = SSLSetCertificate(_contextRef, certificates);// NSLog(@"SSLSetCertificate(): %d", result);
    CFRelease(certificates);
    
    // Perform SSL handshake.
    do {
        result = SSLHandshake(_contextRef);// NSLog(@"SSLHandshake(): %d", result);
    } while(result == errSSLWouldBlock);
    
}

- (void)disconnect {
    
    // Define result variable.
    OSStatus result;
    
    // Close SSL session.
    result = SSLClose(_contextRef);// NSLog(@"SSLClose(): %d", result);
    
    // Release identity.
    if (_identityRef != NULL)
        CFRelease(_identityRef);
    
    // Release certificate.
    if (_certificateRef != NULL)
        CFRelease(_certificateRef);
    
    // Release keychain.
    if (_keychainRef != NULL)
        CFRelease(_keychainRef);
    
    // Close connection to server.
    close((int)_socket);
    
    // Delete SSL context.
    //result = SSLDisposeContext(_contextRef);// NSLog(@"SSLDisposeContext(): %d", result);
    CFRelease(_contextRef);
}

//- (IBAction)pickConfiguration:(NSPopUpButton*)sender {
//    _production = [sender indexOfSelectedItem] == 1;
//}
//
//- (IBAction)pickApp:(NSPopUpButton*)sender {
//    _app = [sender indexOfSelectedItem];
//}

#pragma mark IBAction

- (IBAction)push:(id)sender {
    [self disconnect];
    [self connect];
    if (![[NSFileManager defaultManager] fileExistsAtPath:_certificatePath]) {
        
        return;
    }
    // Validate input.
    if(self.deviceToken == nil || self.payload == nil || _certificateRef == NULL) {
        return;
    }
    NSString * deviceTokenHex = [[[self.deviceToken
                                   stringByReplacingOccurrencesOfString: @"<" withString: @""]
                                  stringByReplacingOccurrencesOfString: @">" withString: @""]
                                 stringByReplacingOccurrencesOfString: @" " withString: @""];
    NSData *deviceToken = [self dataFromHexString:deviceTokenHex];
    if (deviceTokenHex.length == 64 && deviceToken) {
        // Create C input variables.
        char *deviceTokenBinary = (char *)[deviceToken bytes];
        char *payloadBinary = (char *)[self.payload UTF8String];
        size_t payloadLength = strlen(payloadBinary);
        
        // Define some variables.
        uint8_t command = 0;
        char message[293];
        char *pointer = message;
        uint16_t networkTokenLength = htons(32);
        uint16_t networkPayloadLength = htons(payloadLength);
        
        // Compose message.
        memcpy(pointer, &command, sizeof(uint8_t));
        pointer += sizeof(uint8_t);
        memcpy(pointer, &networkTokenLength, sizeof(uint16_t));
        pointer += sizeof(uint16_t);
        memcpy(pointer, deviceTokenBinary, 32);
        pointer += 32;
        memcpy(pointer, &networkPayloadLength, sizeof(uint16_t));
        pointer += sizeof(uint16_t);
        memcpy(pointer, payloadBinary, payloadLength);
        pointer += payloadLength;
        
        // Send message over SSL.
        size_t processed = 0;
        OSStatus result = SSLWrite(_contextRef, &message, (pointer - message), &processed);
        if (result != noErr)
            NSLog(@"SSLWrite(): %d %zd", result, processed);
    } else {
        
    }
}

- (NSData*)dataFromHexString:(NSString *)hexString{
    int j = 0;
    hexString = [hexString stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (!(hexString && [hexString length] > 0 && [hexString length]%2 == 0)) {
        return nil;
    }
    Byte bytes[[hexString length]/2];
    for (int i=0 ; i < [hexString length] ; i++) {
        int int_ch;
        
        unichar hex_char1 = [hexString characterAtIndex:i];
        int int_ch1;
        if(hex_char1 >= '0' && hex_char1 <= '9')
            int_ch1 = (hex_char1 - 48) * 16;
        else if(hex_char1 >= 'A' && hex_char1 <= 'F')
            int_ch1 = (hex_char1 - 55) * 16;
        else if(hex_char1 >= 'a' && hex_char1 <= 'f')
            int_ch1 = (hex_char1 - 87) * 16;
        else
            return nil;
        i++;
        
        unichar hex_char2 = [hexString characterAtIndex:i];
        int int_ch2;
        if(hex_char2 >= '0' && hex_char2 <= '9')
            int_ch2 = (hex_char2 - 48);
        else if(hex_char2 >= 'A' && hex_char2 <= 'F')
            int_ch2 = hex_char2 - 55;
        else if(hex_char2 >= 'a' && hex_char2 <= 'f')
            int_ch2 = hex_char2 - 87;
        else
            return nil;
        
        int_ch = int_ch1 + int_ch2;
        bytes[j] = int_ch;
        j++;
    }
    return [[NSData alloc] initWithBytes:bytes length:[hexString length]/2];
}
@end

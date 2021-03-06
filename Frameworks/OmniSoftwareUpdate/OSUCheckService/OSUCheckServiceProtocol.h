// Copyright 2015 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Id$

@class OSURunOperationParameters;
@protocol OSULookupCredential;

@protocol OSUCheckService

// The runtimeStatsAndProbes are passed on their own since XPC's secure coding doesn't allow for complex data.
- (void)performCheck:(OSURunOperationParameters *)parameters runtimeStatsAndProbes:(NSDictionary *)runtimeStatsAndProbes lookupCredential:(id <OSULookupCredential>)lookupCredential withReply:(void (^)(NSDictionary *results, NSError *error))reply;

@end

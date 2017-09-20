//
//  AVIMGenericCommand+AVIMMessagesAdditions.m
//  AVOS
//
//  Created by 陈宜龙 on 15/11/18.
//  Copyright © 2015年 LeanCloud Inc. All rights reserved.
//

#import "AVIMGenericCommand+AVIMMessagesAdditions.h"
#import "AVIMCommon.h"
#import "AVIMErrorUtil.h"
#import "AVIMConversationOutCommand.h"
#import <objc/runtime.h>
#import "AVIMMessage.h"

NSString *const kAVIMConversationOperationQuery = @"query";

static uint16_t _searial_id = 0;

@implementation AVIMGenericCommand (AVIMMessagesAdditions)

- (AVIMCommandResultBlock)callback {
    return objc_getAssociatedObject(self, @selector(callback));
}

- (void)setCallback:(AVIMCommandResultBlock)callback {
    objc_setAssociatedObject(self, @selector(callback), callback, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (BOOL)needResponse {
    NSNumber *needResponseObject = objc_getAssociatedObject(self, @selector(needResponse));
    return [needResponseObject boolValue];
}

- (void)setNeedResponse:(BOOL)needResponse {
    NSNumber *needResponseObject = [NSNumber numberWithBool:needResponse];
    objc_setAssociatedObject(self, @selector(needResponse), needResponseObject, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (AVIMGenericCommand *)avim_addRequiredKeyWithCommand:(AVIMMessage *)command {
    AVIMCommandType commandType = self.cmd;
    AVIMGenericCommandBuilder *builder = [AVIMGenericCommand builderWithPrototype:self];
    
    switch (commandType) {
            
        case AVIMCommandTypeSession:
            builder.sessionMessage = (AVIMSessionCommand *)command;
            break;
            
        case AVIMCommandTypeConv:
            builder.convMessage = (AVIMConvCommand *)command;
            break;
            
        case AVIMCommandTypeDirect:
            builder.directMessage = (AVIMDirectCommand *)command;
            break;
            
        case AVIMCommandTypeAck:
            builder.ackMessage = (AVIMAckCommand *)command;
            self.needResponse = NO;
            break;
            
        case AVIMCommandTypeRcp:
            builder.rcpMessage = (AVIMRcpCommand *)command;
            break;
            
        case AVIMCommandTypeUnread:
            builder.unreadMessage = (AVIMUnreadCommand *)command;
            break;
            
        case AVIMCommandTypeLogs:
            builder.logsMessage = (AVIMLogsCommand *)command;
            break;
            
        case AVIMCommandTypeError:
            builder.errorMessage = (AVIMErrorCommand *)command;
            break;
            
        case AVIMCommandTypeData:
            builder.dataMessage = (AVIMDataCommand *)command;
            break;
            
        case AVIMCommandTypeRoom:
            builder.roomMessage = (AVIMRoomCommand *)command;
            break;
            
        case AVIMCommandTypeRead:
            builder.readMessage = (AVIMReadCommand *)command;
            break;
            
        case AVIMCommandTypePresence :
            builder.presenceMessage = (AVIMPresenceCommand *)command;
            break;
            
        case AVIMCommandTypeReport:
            builder.reportMessage = (AVIMReportCommand *)command;
            break;
    }
    return [builder build];
}

- (AVIMGenericCommand *)avim_addRequiredKeyForConvMessageWithSignature:(AVIMSignature *)signature {
    NSAssert(self.hasConvMessage, ([NSString stringWithFormat:@"before call %@, make sure you have called `-avim_addRequiredKey`", NSStringFromSelector(_cmd)]));
    if (signature) {
        AVIMGenericCommandBuilder *builder = [AVIMGenericCommand builderWithPrototype:self];
        AVIMConvCommandBuilder *convBuilder = [AVIMConvCommand builderWithPrototype:builder.convMessage];
        convBuilder.s = signature.signature;
        convBuilder.t = signature.timestamp;
        convBuilder.n = signature.nonce;
        builder.convMessage = [convBuilder build];
        return [builder build];
    } else {
        return self;
    }
}

- (AVIMGenericCommand *)avim_addRequiredKeyForSessionMessageWithSignature:(AVIMSignature *)signature {
    NSAssert(self.hasSessionMessage, ([NSString stringWithFormat:@"before call %@, make sure you have called `-avim_addRequiredKey`", NSStringFromSelector(_cmd)]));
    if (signature) {
        /* `st` and `s t n` are The mutex relationship, If you want `s t n` there is no need to add `st`. Otherwise, it will case SESSION_TOKEN_EXPIRED error, and this may cause an error whose code is 1001(Stream end encountered), 4108(LOGIN_TIMEOUT) */
        AVIMGenericCommandBuilder *builder = [AVIMGenericCommand builderWithPrototype:self];
        AVIMSessionCommandBuilder *sessionBuilder = [AVIMSessionCommand builderWithPrototype:builder.sessionMessage];
        if (self.sessionMessage.hasSt) {
            sessionBuilder.st = nil;
        }
        sessionBuilder.s = signature.signature;
        sessionBuilder.t = signature.timestamp;
        sessionBuilder.n = signature.nonce;
        builder.sessionMessage = [sessionBuilder build];
        return [builder build];
    } else {
        return self;
    }
}

- (AVIMGenericCommand *)avim_addRequiredKeyForDirectMessageWithMessage:(AVIMMessage *)message transient:(BOOL)transient {
    NSAssert(self.hasDirectMessage, ([NSString stringWithFormat:@"before call %@, make sure you have called `-avim_addRequiredKey`", NSStringFromSelector(_cmd)]));
    if (message) {
        AVIMGenericCommandBuilder *builder = [AVIMGenericCommand builderWithPrototype:self];
        AVIMDirectCommandBuilder *directBuilder = [AVIMDirectCommand builderWithPrototype:builder.directMessage];
        builder.peerId = message.clientId;
        directBuilder.cid = message.conversationId;
        directBuilder.msg = message.payload;
        directBuilder.transient = transient;
        AVIMDirectCommand *directMessage = [directBuilder build];
        directMessage.message = message;
        builder.directMessage = directMessage;
        return [builder build];
    } else {
        return self;
    }
}

- (AVIMGenericCommand *)avim_addOrRefreshSerialId {
    AVIMGenericCommandBuilder *builder = [AVIMGenericCommand builderWithPrototype:self];
    builder.i = [[self class] nextSerialId];
    return [builder build];
}

+ (uint16_t)nextSerialId {
    if (_searial_id == 0) {
        ++_searial_id;
    }
    uint16_t result = _searial_id;
    _searial_id = (_searial_id + 1) % (UINT16_MAX + 1);
    return result;
}

- (BOOL)avim_validateCommand:(NSError **)error {
    BOOL isValidatedCommand = YES;
    NSString *key;
    NSArray *requiredConditions = [self avim_requiredConditions];
    for (NSInvocation *invocation in requiredConditions) {
        [invocation invoke];
        [invocation getReturnValue:&isValidatedCommand];
        if (!isValidatedCommand) {
            if (error) {
                SEL selector;
                [invocation getArgument:&selector atIndex:1];
                key = NSStringFromSelector(selector);
                *error = [self avim_missingKey:key];
            }
            return NO;
        }
    }
    return isValidatedCommand;
}

- (NSInvocation *)avim_invocation:(SEL)selector target:(id)target {
    NSMethodSignature* signature = [target methodSignatureForSelector:selector];
    //FIXME:Crash
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:target];
    [invocation setSelector:selector];
    return invocation;
}

- (NSArray *)avim_requiredConditions {
    NSMutableArray *requiredKeys = [NSMutableArray array];
    AVIMCommandType commandType = self.cmd;
    switch (commandType) {
            
        case AVIMCommandTypeSession:
            [requiredKeys addObjectsFromArray:({
                NSArray *array = @[
                                   [self avim_invocation:@selector(hasCmd) target:self],
                                   [self avim_invocation:@selector(hasOp) target:self],
                                   [self avim_invocation:@selector(hasPeerId) target:self]
                                   ];
                array;
            })];
            
            break;
            
        case AVIMCommandTypeConv:
            //@[@"cmd", @"op", @"peerId"];
            [requiredKeys addObjectsFromArray:({
                NSArray *array = @[
                                   [self avim_invocation:@selector(hasCmd) target:self],
                                   [self avim_invocation:@selector(hasOp) target:self],
                                   [self avim_invocation:@selector(hasPeerId) target:self]
                                   ];
                array;
            })];
            
            if (self.op == AVIMOpTypeAdd || self.op == AVIMOpTypeRemove) {
                [requiredKeys addObjectsFromArray:({
                    NSArray *array = @[
                                       [self avim_invocation:@selector(hasCid) target:self.convMessage],
                                       [self avim_invocation:@selector(mArray_Count) target:self.convMessage],
                                       ];
                    array;
                })];
                
            } else if (self.op == AVIMOpTypeUpdate) {
                [requiredKeys addObjectsFromArray:({
                    NSArray *array = @[
                                       [self avim_invocation:@selector(hasCid) target:self.convMessage],
                                       [self avim_invocation:@selector(hasAttr) target:self.convMessage],
                                       ];
                    array;
                })];
            }
            
            
            break;
            
        case AVIMCommandTypeDirect:
            // @[@"cmd", @"peerId", @"cid", @"msg"];
            [requiredKeys addObjectsFromArray:({
                NSArray *array = @[
                                   [self avim_invocation:@selector(hasCmd) target:self],
                                   [self avim_invocation:@selector(hasPeerId) target:self],
                                   [self avim_invocation:@selector(hasCid) target:self.directMessage],
                                   [self avim_invocation:@selector(hasMsg) target:self.directMessage]
                                   ];
                array;
            })];
            break;
            
        case AVIMCommandTypeAck:
            //@[@"cmd", @"peerId", @"cid"];
            [requiredKeys addObjectsFromArray:({
                NSArray *array = @[
                                   [self avim_invocation:@selector(hasCmd) target:self],
                                   [self avim_invocation:@selector(hasPeerId) target:self],
                                   [self avim_invocation:@selector(hasCid) target:self.ackMessage]
                                   ];
                array;
            })];
            
            break;
            
        case AVIMCommandTypeLogs:
            //    return @[@"cmd", @"peerId", @"cid"];
            [requiredKeys addObjectsFromArray:({
                NSArray *array = @[
                                   [self avim_invocation:@selector(hasCmd) target:self],
                                   [self avim_invocation:@selector(hasPeerId) target:self],
                                   [self avim_invocation:@selector(hasCid) target:self.logsMessage]
                                   ];
                array;
            })];
            break;
            
            // AVIMCommandType_Rcp = 4,
            // AVIMCommandType_Unread = 5,
            // AVIMCommandType_Logs = 6,
            // AVIMCommandType_Error = 7,
            // AVIMCommandType_Login = 8,
            // AVIMCommandType_Data = 9,
            // AVIMCommandType_Room = 10,
            // AVIMCommandType_Read = 11,
        default:
            break;
    }
    return [requiredKeys copy];
}

/*!
 仅用于序列化时的内部错误提示，不会暴露给用户
 @param key - key 的格式是 “has+key”，比如 hasCmd
 错误信息举例：
 error=Error Domain=AVOSCloudIMErrorDomain Code=1 "AVIMGenericCommand or its property -- AVIMSessionCommand should hasCmd" UserInfo={NSLocalizedFailureReason=AVIMGenericCommand or its property -- AVIMSessionCommand should hasCmd, reason=AVIMGenericCommand or its property -- AVIMSessionCommand should hasCmd}
 
 @return 将缺失的字段封装为NSError对象
 */
- (NSError *)avim_missingKey:(NSString *)key {
    return [AVIMErrorUtil errorWithCode:kAVIMErrorInvalidCommand reason:[NSString stringWithFormat:@"AVIMGenericCommand or its property -- %@ should %@", [self avim_messageClass], key]];
}

- (BOOL)avim_hasError {
    BOOL hasError = YES;
    do {
        /* 绝大部分会以errorMessage的形式报错 */
        if (self.errorMessage.code > 0) {
            break;
        }
        
        /* 应对情景： App 向一个不存在的 Conversation 发送消息，详见 https://forum.leancloud.cn/t/ios-avim/6125
         
         ackMessage {
            code : 4401
            reason : "INVALID_MESSAGING_TARGET"
            t : 1454507717920
            uid : "sFSadfasdfsd"
         }
         */
        if (self.ackMessage.code > 0) {
            break;
        }
        
        /* 另外，对于情景：单点登录, 由于未上传 deviceToken 就 open，如果用户没有 force 登录，会报错, 详见 https://leanticket.cn/t/leancloud/925
         
         sessionMessage {
            code: 4111
            reason: "SESSION_CONFLICT"
         } 
         这种情况不仅要在此处处理，同时也要在 `-[AVIMClient processSessionCommand:]` 中进行异常处理。
         */
        
        if (self.sessionMessage.code > 0) {
            break;
        }
        
        hasError = NO;
    } while (NO);

    return hasError;
}

- (NSError *)avim_errorWithCode:(int32_t)code appCode:(int32_t)appCode reason:(NSString *)reason detail:(NSString *)detail {
    NSError *error = nil;
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[kAVIMCodeKey] = @(code);
    if (reason) {
        userInfo[kAVIMReasonKey] = reason;
        userInfo[NSLocalizedFailureReasonErrorKey] = reason;
    }
    if (detail) {
        userInfo[kAVIMDetailKey] = detail;
        userInfo[NSLocalizedRecoverySuggestionErrorKey] = detail;
    }
    if (appCode > 0) {
        userInfo[kAVIMAppCodeKey] = @(appCode);
    }
    error = [NSError errorWithDomain:AVOSCloudIMErrorDomain code:code userInfo:userInfo];
    return error;
}

- (NSError *)avim_errorObject {
    if (![self avim_hasError]) {
        return nil;
    }
    
    NSError *error = nil;
    do {
        if (self.errorMessage.code > 0) {
            error = [self avim_errorWithCode:self.errorMessage.code appCode:self.errorMessage.appCode reason:self.errorMessage.reason detail:self.errorMessage.detail];
            break;
        }
        
        if (self.ackMessage.code > 0) {
            error = [self avim_errorWithCode:self.ackMessage.code appCode:self.ackMessage.appCode reason:self.ackMessage.reason detail:nil];
            break;
        }
        
        if (self.sessionMessage.code > 0) {
            error = [self avim_errorWithCode:self.sessionMessage.code appCode:0 reason:self.sessionMessage.reason detail:nil];
            break;
        }
    } while (NO);

    return error;
}

- (AVIMMessage *)avim_messageCommand {
    AVIMMessage *result = nil;
    AVIMCommandType commandType = self.cmd;
    switch (commandType) {
            
        case AVIMCommandTypeSession:
            result = self.sessionMessage;
            break;
            
        case AVIMCommandTypeConv:
            result = self.convMessage;
            break;
            
        case AVIMCommandTypeDirect:
            result = self.directMessage;
            break;
            
        case AVIMCommandTypeAck:
            result = self.ackMessage;
            break;
            
        case AVIMCommandTypeRcp:
            result = self.rcpMessage;
            break;
            
        case AVIMCommandTypeUnread:
            result = self.unreadMessage;
            break;
            
        case AVIMCommandTypeLogs:
            result = self.logsMessage;
            break;
            
        case AVIMCommandTypeError:
            result = self.errorMessage;
            break;
            
        case AVIMCommandTypeData:
            result = self.dataMessage;
            break;
            
        case AVIMCommandTypeRoom:
            result = self.roomMessage;
            break;
            
        case AVIMCommandTypeRead:
            result = self.readMessage;
            break;
            
        case AVIMCommandTypePresence:
            result = self.presenceMessage;
            break;
            
        case AVIMCommandTypeReport:
            result = self.reportMessage;
            break;
    }
    return result;
}

- (AVIMConversationOutCommand *)avim_conversationForCache {
    AVIMConversationOutCommand *command = [[AVIMConversationOutCommand alloc] init];
    [command setObject:self.peerId forKey:@"peerId"];
    [command setObject:kAVIMConversationOperationQuery forKey:@"op"];

    NSData *data = [self.convMessage.where.data dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:NULL];
    [command setObject:[NSMutableDictionary dictionaryWithDictionary:json] forKey:@"where"];
    [command setObject:self.convMessage.sort forKey:@"sort"];
    [command setObject:@(self.convMessage.flag) forKey:@"option"];
    
    if (self.convMessage.hasSkip) {
        [command setObject:@(self.convMessage.skip) forKey:@"skip"];
    }
    [command setObject:@(self.convMessage.limit) forKey:@"limit"];

    //there is no need to add signature for AVIMConversationOutCommand because we won't cache it ,  please go to `- (AVIMGenericCommand *)queryCommand` for more detail
    return command;
}

- (NSString *)avim_messageClass {
    AVIMMessage *command = [self avim_messageCommand];
    Class class = [command class];
    NSString *avim_messageClass = NSStringFromClass(class);
    return avim_messageClass;
}

- (NSString *)avim_description {
    NSString *descriptionString = [self description];
    descriptionString = [descriptionString stringByReplacingOccurrencesOfString:@"\\" withString:@""];
    return descriptionString;
}

@end

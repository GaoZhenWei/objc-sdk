//
//  AVIMCommandFormatter.m
//  AVOSCloudIM
//
//  Created by CHEN YI LONG on 15/11/17.
//  Copyright (c) 2015 LeanCloud Inc. All rights reserved.
//

#import <AVOSCloud/AVOSCloud.h>

#import "AVIMCommandFormatter.h"
#import "AVIMErrorUtil.h"

const NSInteger LCIMErrorCodeSessionTokenExpired = 4112;

@implementation AVIMCommandFormatter

+ (NSString *)commandType:(AVIMCommandType)commandType {
    NSString *commandTypeString;
    switch (commandType) {
        case AVIMCommandTypeSession:
            commandTypeString = @"Session";
            break;
            
        case AVIMCommandTypeConv:
            commandTypeString = @"Conv";
            break;
            
        case AVIMCommandTypeDirect:
            commandTypeString = @"Direc";
            break;
            
        case AVIMCommandTypeAck:
            commandTypeString = @"Ack";
            break;
            
        case AVIMCommandTypeRcp:
            commandTypeString = @"Rcp";
            break;
            
        case AVIMCommandTypeUnread:
            commandTypeString = @"Unread";
            break;
            
        case AVIMCommandTypeLogs:
            commandTypeString = @"Logs";
            break;
            
        case AVIMCommandTypeError:
            commandTypeString = @"Error";
            break;
            
        case AVIMCommandTypeLogin:
            commandTypeString = @"Login";
            break;
            
        case AVIMCommandTypeData:
            commandTypeString = @"Data";
            break;
            
        case AVIMCommandTypeRoom:
            commandTypeString = @"Room";
            break;
            
        case AVIMCommandTypeRead:
            commandTypeString = @"Read";
            break;
            
        case AVIMCommandTypePresence:
            commandTypeString = @"Presence";
            break;
            
        case AVIMCommandTypeReport:
            commandTypeString = @"Report";
            break;
    }
    return commandTypeString;
}

+ (NSString *)signatureActionForKey:(AVIMOpType)action {
    //FIXME:查看一下有哪些地方会触发签名，都可以加上去。
    NSString *actionStr;
    switch (action) {
            
            // AVIMOpType_Add = 2,
        case AVIMOpTypeAdd:
            actionStr = @"invite";
            break;
            
            // AVIMOpType_Remove = 3,
        case AVIMOpTypeRemove:
            actionStr = @"kick";
            break;
            
            // AVIMOpType_Open = 1,
            // 登陆
        case AVIMOpTypeOpen:
            actionStr = @"open";
            break;
            
            // AVIMOpType_Start = 30,
            // 创建对话
        case AVIMOpTypeStart:
            actionStr = @"start";
            break;
            
        default:
            break;
    }
    
    return actionStr;
}

+ (AVIMJsonObjectMessage *)JSONObjectWithDictionary:(NSDictionary *)dictionary {
    AVIMJsonObjectMessage *jsonObjectMesssage = nil;

    if (dictionary && [NSJSONSerialization isValidJSONObject:dictionary]) {
        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&error];

        if ([jsonData length]) {
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            AVIMJsonObjectMessageBuilder *jsonObjectMesssageBuilder = [AVIMJsonObjectMessage builder];
            jsonObjectMesssageBuilder.data = jsonString;
            jsonObjectMesssage = [jsonObjectMesssageBuilder build];
        } else if (error) {
            AVLoggerError(AVLoggerDomainIM, @"Can not stringify dictionary: %@.", error.localizedDescription);
        } else {
            AVLoggerError(AVLoggerDomainIM, @"Empty data for dictionary.");
        }
    }

    return jsonObjectMesssage;
}

+ (NSData *)dataWithJSONObject:(AVIMJsonObjectMessage *)JSONObject {
    NSData *data = [JSONObject.data dataUsingEncoding:NSUTF8StringEncoding];
    return data;
}

@end

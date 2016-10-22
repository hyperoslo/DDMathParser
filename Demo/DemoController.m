//
//  DemoController.m
//  DDMathParser
//
//  Created by Dave DeLong on 12/4/10.
//  Copyright 2010 Home. All rights reserved.
//

#import "DemoController.h"
#import "DDMathEvaluator.h"
#import "DDExpression.h"

@interface DemoController()

- (void)textChanged:(NSNotification *)note;

@end

@implementation DemoController
@synthesize inputField;
@synthesize answerField;
@synthesize variableList;
@synthesize orderedVariables;

- (void)awakeFromNib {
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textChanged:) name:NSControlTextDidChangeNotification object:inputField];
	[answerField setStringValue:@""];
	variables = [[NSMutableDictionary alloc] init];
}

- (DDMathEvaluator *)evaluator {
    if (evaluator == nil) {
        evaluator = [[DDMathEvaluator alloc] init];
        evaluator.resolvesFunctionsAsVariables = YES;
        
        __weak __typeof(self) weakSelf = self;
        [evaluator setVariableResolver:^(NSString *variable) {
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) {
                return (NSNumber *)[strongSelf->variables objectForKey:variable];
            }
            return @0;
        }];
    }
    
    return evaluator;
}

- (NSArray *)variablesAndFunctionsInExpression:(DDExpression *)e {
	NSMutableArray * v = [NSMutableArray array];
    BOOL shouldRecurse = NO;
	if ([e expressionType] == DDExpressionTypeVariable) {
		[v addObject:[e variable]];
    } else if ([e expressionType] == DDExpressionTypeFunction) {
        DDMathEvaluator *eval = [self evaluator];
        if ([[eval registeredFunctions] containsObject:[e function]]) {
            shouldRecurse = YES;
        } else {
            [v addObject:[e function]];
        }
	}
    
    if (shouldRecurse) {
		for (DDExpression * se in [e arguments]) {
			[v addObjectsFromArray:[self variablesAndFunctionsInExpression:se]];
		}
	}
	return v;
}

- (void)updateVariablesWithExpression:(DDExpression *)e {
	NSArray * v = [self variablesAndFunctionsInExpression:e];
	
	NSMutableSet * keysThatShouldBeRemoved = [NSMutableSet setWithArray:[variables allKeys]];
	[keysThatShouldBeRemoved minusSet:[NSSet setWithArray:v]];
	
	[variables removeObjectsForKeys:[keysThatShouldBeRemoved allObjects]];
	for (NSString * variable in v) {
		if ([variables objectForKey:variable] == nil) {
			[variables setObject:@0 forKey:variable];
		}
	}
	
	NSArray * orderedKeys = [[variables allKeys] sortedArrayUsingSelector:@selector(compare:)];
	[self setOrderedVariables:orderedKeys];
}

- (void)evaluate {
    DDMathEvaluator *eval = [self evaluator];
    
	NSString * string = [inputField stringValue];
	NSError *error = nil;
	if ([string length] > 0) {
		DDExpression * expression = [DDExpression expressionFromString:string error:&error];
		if (error == nil) {
			NSLog(@"parsed: %@", expression);
			[self updateVariablesWithExpression:expression];
            NSNumber *result = [eval evaluateExpression:expression withSubstitutions:variables error:&error];
			if (error == nil) {
				[answerField setTextColor:[NSColor blackColor]];
				[answerField setStringValue:[result description]];
			}
		}
	} else {
		[answerField setStringValue:@""];
		[variables removeAllObjects];
	}
	if (error != nil) {
		NSLog(@"error: %@", error);
		[answerField setTextColor:[NSColor redColor]];
	}
	
	[variableList reloadData];		
}

- (void)textChanged:(NSNotification *)note {
	[self evaluate];
}

#pragma mark NSTableView stuff

-(NSInteger) numberOfRowsInTableView:(NSTableView *)tableView {
	return [variables count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	NSString *variable = [orderedVariables objectAtIndex:row];
	if ([[tableColumn identifier] isEqual:@"variable"]) {
		return variable;
	}
	return [variables objectForKey:variable];
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	return [[tableColumn identifier] isEqual:@"value"];
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	NSString * variable = [orderedVariables objectAtIndex:row];
	if (![object isKindOfClass:[NSNumber class]]) {
		NSLog(@"invalid object: %@", object);
		object = [NSNumber numberWithInt:0];
	}
	[variables setObject:object forKey:variable];
	[self evaluate];
}

@end

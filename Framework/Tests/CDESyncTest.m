//
//  CDESyncTest.m
//  Ensembles
//
//  Created by Drew McCormack on 19/09/13.
//  Copyright (c) 2013 Drew McCormack. All rights reserved.
//

#import "CDESyncTest.h"
#import "CDEPersistentStoreEnsemble.h"
#import "CDELocalCloudFileSystem.h"

@implementation CDESyncTest

- (void)setUp
{
    [super setUp];
    
    testRootDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"CDEOneWaySyncTest"];
    [[NSFileManager defaultManager] removeItemAtPath:testRootDirectory error:NULL];
    [[NSFileManager defaultManager] createDirectoryAtPath:testRootDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
    
    // First store
    testStoreFile1 = [testRootDirectory stringByAppendingPathComponent:@"store1.sql"];
    testStoreURL1 = [NSURL fileURLWithPath:testStoreFile1];
    
    NSURL *testModelURL = [[NSBundle bundleForClass:self.class] URLForResource:@"CDEStoreModificationEventTestsModel" withExtension:@"momd"];
    model = [[NSManagedObjectModel alloc] initWithContentsOfURL:testModelURL];
    NSPersistentStoreCoordinator *testPSC1 = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    [testPSC1 addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:testStoreURL1 options:nil error:NULL];
    
    context1 = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
    context1.persistentStoreCoordinator = testPSC1;
    context1.stalenessInterval = 0.0;
    
    cloudRootDir = [testRootDirectory stringByAppendingPathComponent:@"cloudfiles"];
    [[NSFileManager defaultManager] createDirectoryAtPath:cloudRootDir withIntermediateDirectories:YES attributes:nil error:NULL];
    
    cloudFileSystem1 = [[CDELocalCloudFileSystem alloc] initWithRootDirectory:cloudRootDir];
    eventDataRoot1 = [testRootDirectory stringByAppendingPathComponent:@"eventData1"];
    ensemble1 = [[CDEPersistentStoreEnsemble alloc] initWithEnsembleIdentifier:@"com.onewaytest" persistentStorePath:testStoreURL1.path managedObjectModelURL:testModelURL cloudFileSystem:cloudFileSystem1 localDataRootDirectory:eventDataRoot1];
    
    // Second store
    testStoreFile2 = [testRootDirectory stringByAppendingPathComponent:@"store2.sql"];
    testStoreURL2 = [NSURL fileURLWithPath:testStoreFile2];
    
    NSPersistentStoreCoordinator *testPSC2 = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    [testPSC2 addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:testStoreURL2 options:nil error:NULL];
    
    context2 = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
    context2.persistentStoreCoordinator = testPSC2;
    context2.stalenessInterval = 0.0;
    
    cloudRootDir = [testRootDirectory stringByAppendingPathComponent:@"cloudfiles"];
    cloudFileSystem2 = [[CDELocalCloudFileSystem alloc] initWithRootDirectory:cloudRootDir];
    eventDataRoot2 = [testRootDirectory stringByAppendingPathComponent:@"eventData2"];
    ensemble2 = [[CDEPersistentStoreEnsemble alloc] initWithEnsembleIdentifier:@"com.onewaytest" persistentStorePath:testStoreURL2.path managedObjectModelURL:testModelURL cloudFileSystem:cloudFileSystem2 localDataRootDirectory:eventDataRoot2];
}

- (void)tearDown
{
    [ensemble1 stopMonitoringSaves];
    [ensemble2 stopMonitoringSaves];
    
    [context1 reset];
    [context2 reset];
    
    [[NSFileManager defaultManager] removeItemAtPath:testRootDirectory error:NULL];
    
    [super tearDown];
}

- (void)waitForAsync
{
    CFRunLoopRun();
}

- (void)completeAsync
{
    CFRunLoopStop(CFRunLoopGetCurrent());
}

- (void)leechStores
{
    [ensemble1 leechPersistentStoreWithCompletion:^(NSError *error) {
        XCTAssertNil(error, @"Error leeching first store");
        [ensemble2 leechPersistentStoreWithCompletion:^(NSError *error) {
            XCTAssertNil(error, @"Error leeching second store");
            [self completeAsync];
        }];
    }];
    [self waitForAsync];
}

- (NSError *)mergeEnsemble:(CDEPersistentStoreEnsemble *)ensemble
{
    __block NSError *returnError = nil;
    [ensemble mergeWithCompletion:^(NSError *error) {
        returnError = error;
        [self completeAsync];
    }];
    [self waitForAsync];
    return returnError;
}

- (NSError *)syncChanges
{
    __block NSError *returnError = nil;
    [self mergeEnsemble:ensemble1];
    if (returnError) return returnError;
    
    [self mergeEnsemble:ensemble2];
    if (returnError) return returnError;
    
    [self mergeEnsemble:ensemble1];
    if (returnError) return returnError;
    
    [self mergeEnsemble:ensemble2];
    if (returnError) return returnError;
    
    return returnError;
}

@end

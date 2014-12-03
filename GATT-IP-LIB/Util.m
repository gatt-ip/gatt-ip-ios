/* The MIT License
 
 Copyright (c) 2010-2014 Vensi, Inc. http://gatt-ip.org
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import "Util.h"

@implementation Util
+ (NSString *)peripheralStateStringFromPeripheralState:(CBPeripheralState )peripheralState
{
    switch (peripheralState)
    {
        case CBPeripheralStateDisconnected:
            return kDisconnected;
        case CBPeripheralStateConnecting:
            return kConnecting;
        case CBPeripheralStateConnected :
            return kConnected;
    }
}

+ ( NSString *)centralStateStringFromCentralState:(CBCentralManagerState )centralState
{
    switch (centralState) {
        case CBCentralManagerStateUnknown:
            return kUnknown;
        case CBCentralManagerStateResetting:
            return kResetting;
        case CBCentralManagerStateUnsupported:
            return kUnsupported;
        case CBCentralManagerStateUnauthorized:
            return kUnauthorized;
        case CBCentralManagerStatePoweredOff:
            return kPoweredOff;
        case CBCentralManagerStatePoweredOn:
            return kPoweredOn;
    }
}

+ (NSString *)peripheralUUIDStringFromPeripheral:(CBPeripheral *)peripheral
{
    NSUUID *peripheralIdentifier = [peripheral identifier];
    return  [peripheralIdentifier UUIDString];
}

+ (NSArray *)listOfServiceCBUUIDObjectsFrom:(NSArray *)arrayOfServiceUUIDStrings
{
    NSMutableArray *listOfServiceCBUUIDs = [[NSMutableArray alloc] init];
    for (NSString *serviceUUIDString in arrayOfServiceUUIDStrings)
    {
        CBUUID *aserviceUUID = [CBUUID UUIDWithString:serviceUUIDString];
        [listOfServiceCBUUIDs addObject:aserviceUUID];
    }
    
    if(listOfServiceCBUUIDs.count > 0)
    {
        return  listOfServiceCBUUIDs;
    }
    return nil;
}

+ (CBPeripheral *)peripheralIn:(NSMutableDictionary *)peripheralCollection  withNSUUID:(NSUUID *)peripheralIdentifier;
{
    CBPeripheral *requestedPeripheral;
    NSArray *listOfPeripheralsInPeripheralCollectoin = [peripheralCollection allValues];
    for (CBPeripheral *peripheralItr in listOfPeripheralsInPeripheralCollectoin)
    {
        if([peripheralItr.identifier isEqual:peripheralIdentifier])
        {
            requestedPeripheral = peripheralItr;
            break;
        }
    }
    
    return  requestedPeripheral;
}

+ (NSDictionary *)serviceIn:(NSMutableDictionary *)peripheralCollection  withCBUUID:(CBUUID *)serviceUUID;
{
    NSArray *listOfPeripheralsInPeripheralCollectoin = [peripheralCollection allValues];
    for (CBPeripheral *peripheral in listOfPeripheralsInPeripheralCollectoin)
    {
        for (CBService *service in peripheral.services)
        {
            if([service.UUID isEqual:serviceUUID ])
            {
                return  @{peripheralKey:peripheral,serviceKey:service};
            }
        }
    }
    return  nil;
}

+ (NSDictionary *)characteristicIn:(NSMutableDictionary *)peripheralCollection  withCBUUID:(CBUUID *)kCharacteristicUUID
{
    NSArray *listOfPeripheralsInPeripheralCollectoin = [peripheralCollection allValues];
    for (CBPeripheral *peripheral in listOfPeripheralsInPeripheralCollectoin)
    {
        for (CBService *service in peripheral.services)
        {
            for (CBCharacteristic *characteristic in service.characteristics)
            {
                if([characteristic.UUID isEqual:kCharacteristicUUID])
                {
                    return  @{characteristicKey:characteristic,peripheralKey:peripheral};
                }
            }
        }
    }
    return nil;
}

+ (NSDictionary *)descriptorIn:(NSMutableDictionary *)peripheralCollection withCBUUID:(CBUUID *)descriptorUUID
{
    NSArray *listOfPeripheralsInPeripheralCollectoin = [peripheralCollection allValues];
    for (CBPeripheral *peripheral in listOfPeripheralsInPeripheralCollectoin)
    {
        for (CBService *service in peripheral.services)
        {
            for (CBCharacteristic *characteristic in service.characteristics)
            {
                for (CBDescriptor *descriptor in characteristic.descriptors)
                {
                    if([descriptor.UUID isEqual:descriptorUUID])
                    {
                        return @{descriptorKey:descriptor,peripheralKey:peripheral};
                    }
                }
            }
        }
    }
    return  nil;
}

+ (NSArray *)listOfJsonServicesFrom:(NSArray *)arrayOfServices
{
    NSMutableArray *jsonList = [[NSMutableArray alloc] init];
    for (CBService *service in arrayOfServices)
    {
        NSString *serviceUUIDString = [service.UUID UUIDString];
        [jsonList addObject:@{kServiceUUID:serviceUUIDString, kIsPrimaryKey:[NSNumber numberWithBool:service.isPrimary]}];
    }
    return  jsonList;
}

+ (NSArray *)listOfJsonCharacteristicsFrom:(NSArray *)arrayOfCharacteristic
{
    NSMutableArray *jsonList = [[NSMutableArray alloc] init];
    for (CBCharacteristic *aCharacteristic in arrayOfCharacteristic)
    {
        NSString *characteristcUUIDString = [[aCharacteristic UUID] UUIDString];
        NSString *characteristcProperty = [NSString stringWithFormat:@"%lu",aCharacteristic.properties ];

        NSData   *characteristcValue = [aCharacteristic value];
        NSString *characteristcValueString = [Util nsDataToHex:characteristcValue];
        [jsonList addObject:@{kIsNotifying:[NSNumber numberWithBool:aCharacteristic.isNotifying],
                              kProperties:characteristcProperty,
                              kCharacteristicUUID:characteristcUUIDString,
                              kValue:characteristcValueString
                              }];
    }
    return jsonList;
}

+ (NSArray *)listOfJsonDescriptorsFrom:(NSArray *)arrayOfDescriptors
{
    NSMutableArray *jsonList = [[NSMutableArray alloc] init];
    for (CBDescriptor *descriptor in arrayOfDescriptors)
    {
        NSString *descriptorUUIDString = [[descriptor UUID]UUIDString];
        [jsonList addObject:@{kDescriptorUUID:descriptorUUIDString}];
        
    }
    return jsonList;
}

+ (NSString *)stringDescriptorValueFrom:(CBDescriptor *)descriptor
{
    NSString *descriptorUUIDString = [[descriptor UUID]UUIDString];
    
    NSNumber *numberDescriptorValue ;
    NSString *stringDescriptorValue;
    NSData *dataDescriptorValue ;
    if([descriptorUUIDString isEqualToString:CBUUIDCharacteristicExtendedPropertiesString])
    {
        numberDescriptorValue = descriptor.value;
    }
    else if ([descriptorUUIDString isEqualToString:CBUUIDCharacteristicUserDescriptionString])
    {
        stringDescriptorValue = descriptor.value;
    }
    else if([descriptorUUIDString isEqualToString:CBUUIDClientCharacteristicConfigurationString])
    {
        numberDescriptorValue = descriptor.value;
    }
    else if ([descriptorUUIDString isEqualToString:CBUUIDServerCharacteristicConfigurationString])
    {
        numberDescriptorValue = descriptor.value;
    }
    else if([descriptorUUIDString isEqualToString:CBUUIDCharacteristicFormatString])
    {
        dataDescriptorValue = descriptor.value;
    }
    else if ([descriptorUUIDString isEqualToString:CBUUIDCharacteristicAggregateFormatString])
    {
        numberDescriptorValue = descriptor.value;
    }
    
    //value is being packaged into a string
    NSString *desscriptorValueString ;
    if(numberDescriptorValue)
    {
        desscriptorValueString = [NSString stringWithFormat:@"%@",numberDescriptorValue];
    }
    else if (dataDescriptorValue)
    {
        desscriptorValueString = [[NSString alloc]initWithData:dataDescriptorValue encoding:NSUTF8StringEncoding];
    }
    else
    {
        desscriptorValueString = stringDescriptorValue;
    }
    return  desscriptorValueString;
}

+ (NSString*) nsDataToHex:(NSData*)data
{
    const unsigned char *dbytes = [data bytes];
    NSMutableString *hexStr =
    [NSMutableString stringWithCapacity:[data length]*2];
    int i;
    for (i = 0; i < [data length]; i++) {
        [hexStr appendFormat:@"%02x", dbytes[i]];
    }
    return [NSString stringWithString: hexStr];
}

+ (NSMutableData*) hexToNSData:(NSString *) command
{
    
    command = [command stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSMutableData *commandToSend= [[NSMutableData alloc] init];
    unsigned char whole_byte;
    char byte_chars[3] = {'\0','\0','\0'};
    for (int i = 0; i < ([command length] / 2); i++) {
        byte_chars[0] = [command characterAtIndex:i*2];
        byte_chars[1] = [command characterAtIndex:i*2+1];
        whole_byte = strtol(byte_chars, NULL, 16);
        [commandToSend appendBytes:&whole_byte length:1];
    }
    NSLog(@"%@", commandToSend);
    return commandToSend;
}

+ (CBCharacteristicWriteType )writeTypeForCharacteristicGiven:(NSString *)stringWriteType
{
    if([stringWriteType isEqualToString:kWriteWithoutResponse])
    {
        
        return CBCharacteristicWriteWithoutResponse;
    }
    return CBCharacteristicWriteWithResponse;
}

+ (NSString *)humanReadableFormatFromHex:(NSString *)hexString
{
    NSDictionary *methods =  @{@"aa":@"Configure",
                               @"ab":@"ScanForPeripherals",
                               @"ac":@"StopScanning",
                               @"ad":@"Connect",
                               @"ae":@"Disconnect",
                               @"af":@"CentralState",
                               @"ag":@"GetConnectedPeripherals",
                               @"ah":@"GetPerhipheralsWithServices",
                               @"ai":@"GetPerhipheralsWithIdentifiers",
                               @"ak":@"GetServices",
                               @"al":@"GetIncludedServices",
                               @"am":@"GetCharacteristics",
                               @"an":@"GetDescriptors",
                               @"ao":@"GetCharacteristicValue",
                               @"ap":@"GetDescriptorValue",
                               @"aq":@"WriteCharacteristicValue",
                               @"ar":@"WriteDescriptorValue",
                               @"as":@"SetValueNotification",
                               @"at":@"GetPeripheralState",
                               @"au":@"GetRSSI",
                               @"av":@"InvalidatedServices",
                               @"aw":@"peripheralNameUpdate",
                               };
    
    NSDictionary *keys = @{@"ba":@"centralUUID",
                           @"bb":@"peripheralUUID",
                           @"bc":@"PeripheralName",
                           @"bd":@"PeripheralUUIDs",
                           @"be":@"ServiceUUID",
                           @"bf":@"ServiceUUIDs",
                           @"bg":@"peripherals",
                           @"bh":@"IncludedServiceUUIDs",
                           @"bi":@"CharacteristicUUID",
                           @"bj":@"CharacteristicUUIDs",
                           @"bk":@"DescriptorUUID",
                           @"bl":@"Services",
                           @"bm":@"Characteristics",
                           @"bn":@"Descriptors",
                           @"bo":@"Properties",
                           @"bp":@"Value",
                           @"bq":@"State",
                           @"br":@"StateInfo",
                           @"bs":@"StateField",
                           @"bt":@"WriteType",
                           @"bu":@"RSSIkey",
                           @"bv":@"IsPrimaryKey",
                           @"bw":@"IsBroadcasted",
                           @"bx":@"IsNotifying",
                           @"by":@"ShowPowerAlert",
                           @"bz":@"IdentifierKey",
                           @"b0":@"ScanOptionAllowDuplicatesKey",
                           @"b1":@"ScanOptionSolicitedServiceUUIDs",
                           @"b2":@"AdvertisementDataKey",
                           @"b3":@"CBAdvertisementDataManufacturerDataKey",
                           @"b4":@"CBAdvertisementDataServiceUUIDsKey",
                           @"b5":@"CBAdvertisementDataServiceDataKey",
                           @"b6":@"CBAdvertisementDataOverflowServiceUUIDsKey",
                           @"b7":@"CBAdvertisementDataSolicitedServiceUUIDsKey",
                           @"b8":@"CBAdvertisementDataIsConnectable",
                           @"b9":@"CBAdvertisementDataTxPowerLevel",
                           @"da":@"CBCentralManagerRestoredStatePeripheralsKey",
                           @"db":@"CBCentralManagerRestoredStateScanServicesKey"
                           };
    
    NSDictionary *values = @{@"cc":@"WriteWithResponse",
                             @"cd":@"WriteWithoutResponse",
                             @"ce":@"NotifyOnConnection",
                             @"cf":@"NotifyOnDisconnection",
                             @"cg":@"NotifyOnNotification",
                             @"ch":@"Disconnected",
                             @"ci":@"Connecting",
                             @"cj":@"Connected",
                             @"ck":@"Unknown",
                             @"cl":@"Resetting",
                             @"cm":@"Unsupported",
                             @"cn":@"Unauthorized",
                             @"co":@"PoweredOff",
                             @"cp":@"PoweredOn"};

    if([methods valueForKey:hexString])
    {
        return [methods valueForKey:hexString];
    }
    else if ([keys valueForKey:hexString])
    {
        return [keys valueForKey:hexString];
    }
    else if([values valueForKey:hexString])
    {
        return [values valueForKey:hexString];
    }

    return hexString ? hexString : @"";
}

+ (NSArray *)listOfServiceUUIDStrings:(NSArray *)input
{
    NSMutableArray *listService = [NSMutableArray new];
    NSString *aServiceString;
    for (CBUUID *serviceUUID in input)
    {
        aServiceString = serviceUUID.UUIDString;
        [listService addObject:aServiceString];
    }
    return listService;
}

+ (NSDictionary * )collectionOfServiceAdvertismentData:(NSDictionary *)input
{
    NSMutableDictionary *mutatedServiceAdevertismentData = [NSMutableDictionary new];
    NSString *aServiceString  ;
    NSData *serviceData;
    NSString *hexData;
    for (CBUUID *aService in input)
    {
        aServiceString = aService.UUIDString;
        serviceData = [input objectForKey:aService];
        hexData = [self nsDataToHex:serviceData];
        [mutatedServiceAdevertismentData setObject:hexData forKey:aServiceString];
    }
    return mutatedServiceAdevertismentData;
}

+ (NSDictionary *)peripheralDictionary:(CBPeripheral *)peripheral
{   //extract peripheral info
    NSString *peripehralUUIDString = peripheral.identifier.UUIDString;
    NSString *peripheralNameString =  peripheral.name;
    NSString *peripheralStateString = [self peripheralStateStringFromPeripheralState:peripheral.state];
    //construct the dictionary
    NSDictionary *peripheralDictionary = @{kPeripheralName:peripheralNameString,
                                           kPeripheralUUID:peripehralUUIDString,
                                           kState:peripheralStateString
                                           };
    return peripheralDictionary;
}

+ (NSArray *)listOfPeripherals:(NSArray *)input
{
    NSMutableArray *listOfPeripherals = [NSMutableArray new];
    NSDictionary *aPeripheralDictionary ;
    for (CBPeripheral *aPeripheral in input)
    {
        aPeripheralDictionary = [self peripheralDictionary:aPeripheral];
        [listOfPeripherals addObject:aPeripheralDictionary];
    }
    return listOfPeripherals;
}

@end

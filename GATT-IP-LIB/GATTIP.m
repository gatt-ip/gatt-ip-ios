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


#import "GATTIP.h"
#import "Util.h"
#import <CoreBluetooth/CoreBluetooth.h>

NSInteger MAX_NUMBER_OF_REQUESTS = 60 ;

@interface GATTIP () <CBCentralManagerDelegate,CBPeripheralDelegate>

@property CBCentralManager *centralManager;
@property NSMutableArray *availableDevices;
@property NSMutableDictionary *connectedPeripheralsCollection;
@property NSMutableArray *previousRequests;

@end


@implementation GATTIP
static BOOL isScanning = NO;
static NSDictionary *requestDict;
static NSString *sCBUUID;

- (void)request:(NSData *)gattipMesg
{
    if(!gattipMesg)
    {
        NSDictionary* respDict = @{ kError: @{kCode:kInvalidRequest}};
        [self sendResponse:respDict];
        return;
    }
    
    NSError *jsonError = nil;
    id requests = [NSJSONSerialization JSONObjectWithData:gattipMesg options:0 error:&jsonError];
    if(jsonError)
    {
        NSDictionary* respDict = @{kError: @{kCode:kParseError, kMessageField: jsonError.localizedDescription}};
        [self sendResponse:respDict ];
        return;
    }
    
    if(!requests)
    {
        NSDictionary *respDict = @{kError: @{kCode:kParseError}};
        [self sendResponse:respDict ];
        return;
    }
    
    //expect input to be either a dictionary(1 request) or an array of dictaionaries(multiple Requests)
    if([requests isKindOfClass:[NSDictionary class]])
    {
        requests = [NSArray arrayWithObject:requests];
    } else if (![requests isKindOfClass:[NSArray class]])//if not an array send invalid request and break
    {
        NSDictionary* respDict = @{kError: @{kCode:kInvalidRequest}};
        [self sendResponse:respDict ];
        return;
    }
    
    for (NSDictionary *request in requests)
    {
        [self handleLoggingRequestAndResponse:request];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"GotNewMessage" object: nil];
        if([[request valueForKey:kMethod] isEqualToString:kConfigure])
        {
            [self configure:request];
        }
        else if ([[request valueForKey:kMethod] isEqualToString:kScanForPeripherals])
        {
            [self scanForPeripherals:request];
        }
        else if ([[request valueForKey:kMethod] isEqualToString:kStopScanning])
        {
            [self  stopScanning:request];
        }
        else if ([[request valueForKey:kMethod] isEqualToString:kConnect])
        {
            [self connect:request];
        }
        else if ([[request valueForKey:kMethod] isEqualToString:kDisconnect])
        {
            [self disconnect:request];
        }
        else if ([[request valueForKey:kMethod] isEqualToString:kCentralState])
        {
            [self getCentralState:request];
        }
        else if ([[request valueForKey:kMethod] isEqualToString:kGetConnectedPeripherals])
        {
            [self getConnectedPeripherals:request];
        }
        else if ([[request valueForKey:kMethod] isEqualToString:kGetPerhipheralsWithServices])
        {
            [self getPerhipheralsWithServices:request];
        }
        else if ([[request valueForKey:kMethod] isEqualToString:kGetPerhipheralsWithIdentifiers])
        {
            [self getPerhipheralsWithIdentifiers:request];
        }
        else if ([[request valueForKey:kMethod] isEqualToString:kGetServices])
        {
            [self getServices:request];
        }
        else if ([[request valueForKey:kMethod] isEqualToString:kGetIncludedServices])
        {
            [self getIncludedServices:request];
        }
        else if ([[request valueForKey:kMethod] isEqualToString:kGetCharacteristics])
        {
            [self getCharacteristics:request];
        }
        else if ([[request valueForKey:kMethod] isEqualToString:kGetDescriptors])
        {
            [self getDescriptors:request];
        }
        else if ([[request valueForKey:kMethod] isEqualToString:kGetCharacteristicValue])
        {
            [self getCharacteristicValue:request];
        }
        else if ([[request valueForKey:kMethod] isEqualToString:kGetDescriptorValue])
        {
            [self getDescriptorValue:request];
        }
        else if ([[request valueForKey:kMethod] isEqualToString:kWriteCharacteristicValue])
        {
            [self writeCharacteristicValue:request];
        }
        else if ([[request valueForKey:kMethod] isEqualToString:kSetValueNotification])
        {
            [self setValueNotification:request];
        }
        else if ([[request valueForKey:kMethod] isEqualToString:kGetPeripheralState])
        {
            [self getPeripheralState:request];
        }
        else if ([[request valueForKey:kMethod] isEqualToString:kGetRSSI])
        {
            [self getRSSI:request];
        }
        else if([[request valueForKey:kResult] isEqualToString:kMessage])
        {
        }
        else
        {
            NSDictionary *invalidMethod = @{kError:@{kCode:kMethodNotFound}};
            [self sendResponse:invalidMethod];
        }
    }
}

#pragma mark - Cenetral Manager Delegate Methods
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSString *peripheralUUIDString = [peripheral.identifier UUIDString];
    NSString *peripheralNameString = peripheral.name ? peripheral.name : @"" ;
    NSDictionary *parameters = @{kPeripheralUUID:peripheralUUIDString,
                                 kPeripheralName:peripheralNameString};
    NSDictionary *response = @{kResult:kConnect,
                               kParams:parameters};
    [self sendResponse:response];
    
    peripheral.delegate = self;
    [_connectedPeripheralsCollection setObject:peripheral  forKey:peripheralUUIDString];
}


- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSString *peripheralUUIDString = [peripheral.identifier UUIDString];
    NSDictionary *response;
    NSDictionary *parameters = @{kPeripheralUUID:peripheralUUIDString};
    response = @{kResult:kConnect,
                 kParams:parameters,
                 kError:@{kCode:kError32603, kMessageField:error.localizedDescription}
                 };
    
    [self sendResponse:response];
}


- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSString *peripheralUUIDString = [peripheral.identifier UUIDString];
    NSString *peripheralNameString = peripheral.name ? peripheral.name : @"";
    NSDictionary *parameters = @{kPeripheralUUID:peripheralUUIDString,
                                 kPeripheralName:peripheralNameString};
    NSDictionary *response;
    if(!error)
    {
        NSDictionary *response = @{kResult:kDisconnect,
                                   kParams:parameters};
        [self sendResponse:response];
        [_connectedPeripheralsCollection removeObjectForKey:peripheralUUIDString];
        return;
    }
    response = @{kResult:kDisconnect,
                 kParams:parameters,
                 kError:@{kCode:kError32603, kMessageField:error.localizedDescription}};
    
    [_connectedPeripheralsCollection removeObjectForKey:peripheralUUIDString];
    [self sendResponse:response];
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
    NSString *peripheralUUIDString = [peripheral.identifier UUIDString];
    NSString *peripheralNameString = peripheral.name ? peripheral.name : @"Unknown";
    NSString *RSSIValue = [NSString stringWithFormat:@"%@",RSSI];
    NSDictionary *response;
    NSMutableString *advData = [[NSMutableString alloc] initWithCapacity:62];
    NSMutableDictionary *mutatedAdevertismentData = [NSMutableDictionary new];
    //---CBAdvertisementDataManufacturerDataKey
    NSData *peripheralData = [advertisementData objectForKey:@"kCBAdvDataManufacturerData"];//kCBAdvDataManufacturerData
    if(peripheralData)
    {
        NSString *peripheralDataAsHex = [Util nsDataToHex:peripheralData];
        [advData appendString:[NSString stringWithFormat:@"%02x",(unsigned int)[peripheralData length]+1]];
        [advData appendString:ManufacturerSpecificData];
        [advData appendString:peripheralDataAsHex];
    }
    //---CBAdvertisementDataServiceUUIDsKey
    NSArray *kCBAdvDataServiceUUIDsArray = [advertisementData objectForKey:@"kCBAdvDataServiceUUIDs"];
    if(kCBAdvDataServiceUUIDsArray)
    {
        NSArray *mutatedkCBAdvDataServiceUUIDsArray = [Util listOfServiceUUIDStrings:kCBAdvDataServiceUUIDsArray];
        int length = 0;
        NSMutableString *uuid = [[NSMutableString alloc] init];
        NSString *serviceType = [[NSString alloc] init];
        for(int i =0; i<[mutatedkCBAdvDataServiceUUIDsArray count]; i++) {
            NSString *serviceUUID = [NSString stringWithFormat:@"%@",[mutatedkCBAdvDataServiceUUIDsArray objectAtIndex:i]];
            
            if([serviceUUID length] == 4) {
                length += 2;
                serviceType = ServiceData16bitUUID;
                [uuid appendString:[Util reverseServiceUUID:serviceUUID]];
            } else if([serviceUUID length] == 8) {
                length += 4;
                serviceType = ServiceData32bitUUID;
                serviceUUID = [serviceUUID stringByReplacingOccurrencesOfString:@"-" withString:@""];
                [uuid appendString:[Util reverseServiceUUID:serviceUUID]];
            } else if([serviceUUID length] == 36) {
                length += 16;
                serviceType = ServiceData128bitUUID;
                serviceUUID = [serviceUUID stringByReplacingOccurrencesOfString:@"-" withString:@""];
                [uuid appendString:[Util reverseServiceUUID:serviceUUID]];
            }
           
        }
        if(length > 0 && [serviceType length] > 0 && [uuid length] > 0) {
            [advData appendString:[NSString stringWithFormat:@"%02x",length+1]];
            [advData appendString:serviceType];
            [advData appendString:uuid];
        }
    }
    //---CBAdvertisementDataServiceDataKey
    NSDictionary *kCBAdvertisementDataServiceDataDictionary = [advertisementData objectForKey:@"kCBAdvDataServiceData"];
    if(kCBAdvertisementDataServiceDataDictionary)
    {
        NSDictionary *mutatedkCBAdvertisementDataServiceDataDictionary = [Util collectionOfServiceAdvertismentData:kCBAdvertisementDataServiceDataDictionary];
    }
    
    //---CBAdvertisementDataOverflowServiceUUIDsKey
    NSArray *kCBAdvertisementDataOverflowServiceUUIDArray = [advertisementData objectForKey:@"kCBAdvDataOverflowServiceUUIDs"];
    if(kCBAdvertisementDataOverflowServiceUUIDArray)
    {
        NSArray *mutatedkCBAdvertisementDataOverflowServiceUUIDArray = [Util listOfServiceUUIDStrings:kCBAdvertisementDataOverflowServiceUUIDArray];
    }
    
    //---CBAdvertisementDataSolicitedServiceUUIDsKey
    NSArray *kCBAdvertisementDataSolicitedServiceUUIDArray = [advertisementData objectForKey:@"kCBAdvDataSolicitedServiceUUIDs"];
    if(kCBAdvertisementDataSolicitedServiceUUIDArray)
    {
        NSArray *mutatedkCBAdvertisementDataSolicitedServiceUUIDArray = [Util listOfServiceUUIDStrings:kCBAdvertisementDataSolicitedServiceUUIDArray];
    }
    
    //---CBAdvertisementDataIsConnectable
    NSNumber *kCBAdvertisementDataIsConnectableValue = [advertisementData objectForKey:@"kCBAdvDataIsConnectable"];
    
    [advData appendString:[NSString stringWithFormat:@"%02x",2]];
    [advData appendString:ADFlags];
    
    [advData appendString:[NSString stringWithFormat:@"%02x",[kCBAdvertisementDataIsConnectableValue intValue]]];
    
    //--CBAdvertisementDataTxPowerLevelKey
    NSNumber *kCBAdvertisementDataTxPowerLevelKey = [advertisementData objectForKey:@"kCBAdvDataTxPowerLevel"];
    if(kCBAdvertisementDataTxPowerLevelKey)
    {
        NSString *powerKey = [kCBAdvertisementDataTxPowerLevelKey stringValue];
        [advData appendString:[NSString stringWithFormat:@"%02x",(unsigned int)[powerKey length]+1]];
        [advData appendString:TxPowerLevel];
        if([powerKey intValue] < 10 && [powerKey intValue] >= 0)
            [advData appendString:[NSString stringWithFormat:@"0%@",powerKey]];
        else
            [advData appendString:[NSString stringWithFormat:@"%@",powerKey]];
        
    }
    
    [mutatedAdevertismentData setObject:advData forKeyedSubscript:kRawAdvertisementData];
    
    NSString *btAddr = [NSString stringWithFormat:@""];
    
    NSDictionary *parameters = @{ kAdvertisementDataKey:mutatedAdevertismentData,
                                  kRSSIkey:RSSIValue,
                                  kPeripheralUUID:peripheralUUIDString,
                                  kPeripheralName:peripheralNameString,
                                  kPeripheralBtAddress : btAddr};
    
    
    response = @{kResult:kScanForPeripherals,
                 kParams:parameters};
    
    [_availableDevices addObject:peripheral];
    [self sendResponse:response];
    
}

- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary *)dict
{
    NSMutableDictionary *mutatedDict = [NSMutableDictionary new];
    //CBCentralManagerRestoredStatePeripheralsKey
    NSArray *kCBCentralManagerRestoredStatePeripheralArray = [dict valueForKey:@"kCBRestoredPeripherals"];
    if(kCBCentralManagerRestoredStatePeripheralArray)
    {
        NSArray *mutatedkCBCentralManagerRestoredStatePeripheralArray = [Util listOfPeripherals:kCBCentralManagerRestoredStatePeripheralArray];
        [mutatedDict setObject:mutatedkCBCentralManagerRestoredStatePeripheralArray forKey:kCBCentralManagerRestoredStatePeripheralsKey];
    }
    
    //CBCentralManagerRestoredStateScanServicesKey
    NSArray *kCBCentralManagerRestoredStateScanServiceArray = [dict valueForKey:@"kCBRestoredScanServices"];
    if(kCBCentralManagerRestoredStateScanServiceArray)
    {
        NSArray *mutatedkCBCentralManagerRestoredStateScanServiceArray = [Util listOfServiceUUIDStrings:kCBCentralManagerRestoredStateScanServiceArray];
        [mutatedDict setObject:mutatedkCBCentralManagerRestoredStateScanServiceArray forKey:kCBCentralManagerRestoredStateScanServicesKey];
    }
    
    //CBCentralManagerRestoredStateScanOptionsKey
    
    NSDictionary *parameters = @{kStateInfo:mutatedDict};
    NSDictionary *response = @{kResult:kCentralState,
                               kParams:parameters};
    
    [self sendResponse:response];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    CBCentralManagerState centeralState = central.state;
    NSString *stateString = [Util centralStateStringFromCentralState:centeralState];
    NSDictionary *parameters = @{kState:stateString};
    NSDictionary *response = @{kParams:parameters,
                               kResult:kCentralState};
    [self sendResponse:response];
}

#pragma mark - Perhipheral Delegate Methods
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverIncludedServicesForService:(CBService *)service error:(NSError *)error
{
    NSDictionary *response;
    NSDictionary *parameters;
    if(!error)
    {
        NSString *peripheralUUIDString = [peripheral.identifier UUIDString];
        NSString *serviceUUIDString = [service.UUID UUIDString];
        NSArray  *discoveredServices = [Util listOfJsonServicesFrom:service.includedServices];
        parameters = @{kPeripheralUUID:peripheralUUIDString,
                       kServiceUUID:serviceUUIDString,
                       kServices:discoveredServices};
        response = @{kResult:kGetIncludedServices,
                     kParams:parameters};
        [self sendResponse:response];
        return;
    }
    NSString *erroMessage = error.localizedDescription ;
    parameters = @{kPeripheralUUID:[peripheral.identifier UUIDString]};
    response = @{kResult:kGetIncludedServices,
                 kParams:parameters,
                 kError:@{kCode:kError32603,kMessageField:erroMessage}};
    [self sendResponse:response];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    NSDictionary *response;
    NSDictionary *parameters;
    if(!error)
    {
        NSString *peripheralUUIDString = [peripheral.identifier UUIDString];
        NSArray *discoveredServices = [Util listOfJsonServicesFrom:peripheral.services];
        parameters = @{kPeripheralUUID:peripheralUUIDString,
                       kServices:discoveredServices};
        response = @{kResult:kGetServices,
                     kParams:parameters};
        [self sendResponse:response];
        return;
    }
    NSString *erroMessage = error.localizedDescription ;
    parameters = @{kPeripheralUUID:[peripheral.identifier UUIDString]};
    response = @{kResult:kGetServices,
                 kParams:parameters,
                 kError:@{kCode:kError32603,kMessageField:erroMessage}};
    [self sendResponse:response];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    NSDictionary *response;
    NSDictionary *parameters;
    NSString *serviceUUIDString = [service.UUID UUIDString];
    NSString *peripheralUUIDString = [peripheral.identifier UUIDString];
    if(!error)
    {
        NSArray  *listOfCharacteristics = [Util listOfJsonCharacteristicsFrom:service.characteristics];
        parameters = @{kPeripheralUUID:peripheralUUIDString,
                       kServiceUUID:serviceUUIDString,
                       kCharacteristics:listOfCharacteristics};
        response = @{kResult:kGetCharacteristics,
                     kParams:parameters};
        [self sendResponse:response];
        return;
    }
    NSString *errorMessage = error.localizedDescription;
    parameters = @{kPeripheralUUID:peripheralUUIDString,
                   kServiceUUID:serviceUUIDString};
    response = @{kResult:kGetCharacteristics,
                 kParams:parameters,
                 kError:@{kCode:kError32603,kMessageField:errorMessage}};
    [self sendResponse:response];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSDictionary *response;
    NSDictionary *parameters;
    NSString *characteristicUUIDString  = [characteristic.UUID UUIDString];
    NSString *peripheralUUIDString = [peripheral.identifier UUIDString];
    if(!error)
    {
        NSArray  *descriptorArray = [Util listOfJsonDescriptorsFrom:characteristic.descriptors];
        parameters = @{kCharacteristicUUID:characteristicUUIDString,
                       kPeripheralUUID:peripheralUUIDString,
                       kServiceUUID:sCBUUID,
                       kDescriptors:descriptorArray};
        response = @{kResult:kGetDescriptors,
                     kParams:parameters};
        [self sendResponse:response];
        return;
    }
    
    NSArray  *descriptorArray = [Util listOfJsonDescriptorsFrom:characteristic.descriptors];
    parameters = @{kCharacteristicUUID:characteristicUUIDString,
                   kPeripheralUUID:peripheralUUIDString,
                   kServiceUUID:sCBUUID,
                   kDescriptors:descriptorArray};
    response = @{kResult:kGetDescriptors,
                 kParams:parameters};
    
    
    
    [self sendResponse:response];
}

- (void)peripheral:(CBPeripheral *)peripheral didModifyServices:(NSArray *)invalidatedServices
{
    NSArray *jsonServices  = [Util listOfJsonServicesFrom:invalidatedServices];
    NSString *peripheralUUIDString = [peripheral.identifier UUIDString];
    NSDictionary *parameters = @{kPeripheralUUID:peripheralUUIDString,
                                 kServices:jsonServices};
    NSDictionary *response = @{kResult:kInvalidatedServices,
                               kParams:parameters};
    [self sendResponse:response];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSDictionary *response;
    NSDictionary *parameters;
    NSString *characteristcUUIDString = [[characteristic UUID] UUIDString];
    NSString *peripheralUUIDString = [peripheral.identifier UUIDString];
    NSString *serviceUUIDString = [characteristic.service.UUID UUIDString];
    if(!error)
    {
        NSString *characteristcProperty = [NSString stringWithFormat:@"%lu",(unsigned long)characteristic.properties];
        NSData   *characteristcValue = [characteristic value];
        NSString *characteristcValueString = [Util nsDataToHex:characteristcValue];
        parameters = @{kIsNotifying:[NSNumber numberWithBool:characteristic.isNotifying],
                       kProperties:characteristcProperty,
                       kCharacteristicUUID:characteristcUUIDString,
                       kPeripheralUUID:peripheralUUIDString,
                       kServiceUUID:serviceUUIDString,
                       kValue:characteristcValueString};
        response = @{kResult:kGetCharacteristicValue,
                     kParams:parameters};
        [self sendResponse:response];
        return;
    }
    //TODO:spec field addition
    NSString *errorMessage = error.localizedDescription;
    parameters = @{kCharacteristicUUID:characteristcUUIDString};
    response = @{kResult:kGetCharacteristicValue,
                 kParams:parameters,
                 kError:@{kCode:kError32603,kMessageField:errorMessage}};
    
    [self sendResponse:response];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error
{
    NSDictionary *response;
    NSDictionary *parameters;
    NSString *descriptorUUIDString = [[descriptor UUID]UUIDString];
    if(!error)
    {
        NSString *descriptorValue = [Util stringDescriptorValueFrom:descriptor];
        parameters = @{kDescriptorUUID:descriptorUUIDString,
                       kValue:descriptorValue};
        response =  @{kResult:kGetDescriptorValue,
                      kParams:parameters};
        
        [self sendResponse:response];
        return;
    }
    NSString *errorMessage = error.localizedDescription;
    parameters = @{kDescriptorUUID:descriptorUUIDString};
    
    response = @{kResult:kGetDescriptorValue,
                 kParams:parameters,
                 kError:@{kCode:kError32603,kMessageField:errorMessage}};
    
    [self sendResponse:response];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSDictionary *response;
    NSDictionary *parameters;
    NSString *characteristicUUIDString = [[characteristic UUID]UUIDString];
    NSString *serviceUUIDString = [[characteristic.service UUID]UUIDString];
    NSString *peripheralUUIDString = [peripheral.identifier UUIDString];
    if(!error)
    {
        NSString *characteristicDataHexString = [Util nsDataToHex:[characteristic value]];
        parameters = @{kCharacteristicUUID:characteristicUUIDString,
                       kPeripheralUUID:peripheralUUIDString,
                       kServiceUUID:serviceUUIDString,
                       kIsNotifying:[NSNumber numberWithBool:characteristic.isNotifying],
                       kValue:characteristicDataHexString};
        response = @{kResult:kSetValueNotification,
                     kParams:parameters};
        
        [self sendResponse:response];
        return;
    }
    parameters = @{kCharacteristicUUID:characteristicUUIDString,
                   kServiceUUID:serviceUUIDString,
                   kPeripheralUUID:peripheralUUIDString};
    NSString *errorMessage = error.localizedDescription;
    response = @{kResult:kSetValueNotification,
                 kParams:parameters,
                 kError:@{kCode:kError32603,kMessageField:errorMessage}};
    [self sendResponse:response];
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSDictionary *response;
    NSDictionary *parameters;
    NSString *characteristicUUIDString = [[characteristic UUID]UUIDString];
    NSString *peripheralUUIDString = [peripheral.identifier UUIDString];
    if(!error)
    {
        parameters = @{kCharacteristicUUID:characteristicUUIDString,
                       kPeripheralUUID:peripheralUUIDString};
        response = @{kResult:kWriteCharacteristicValue,
                     kParams:parameters};
        [self sendResponse:response];
        return;
    }
    NSString *errorMessage = error.localizedDescription;
    parameters = @{kCharacteristicUUID:characteristicUUIDString,
                   kPeripheralUUID:peripheralUUIDString};
    response = @{kResult:kWriteCharacteristicValue,
                 kParams:parameters,
                 kError:@{kCode:kError32603,kMessageField:errorMessage}};
    
    [self sendResponse:response];
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor error:(NSError *)error
{
    NSDictionary *response;
    NSDictionary *parameters;
    NSString *peripheralUUIDString = [peripheral.identifier UUIDString];
    NSString *descriptorUUIDString = [[descriptor UUID ]UUIDString];
    if(!error)
    {
        parameters = @{kDescriptorUUID:descriptorUUIDString,
                       kPeripheralUUID:peripheralUUIDString};
        response = @{kResult:kWriteDescriptorValue,
                     kParams:parameters};
        [self sendResponse:response];
        return;
    }
    parameters = @{kDescriptorUUID:descriptorUUIDString,
                   kPeripheralUUID:peripheralUUIDString};
    NSString *errorMessage = error.localizedDescription;
    response = @{kResult:kWriteDescriptorValue,
                 kParams:parameters,
                 kError:@{kCode:kError32603,kMessageField:errorMessage}};
    
    [self sendResponse:response];
}

- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral
{
    NSString *peripheralUUIDString = [peripheral.identifier UUIDString];
    NSDictionary *parameters = @{kPeripheralUUID:peripheralUUIDString,
                                 kPeripheralName:peripheral.name };
    NSDictionary *response = @{kResult:kPeripheralNameUpdate,
                               kParams:parameters};
    [self sendResponse:response];
}

- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSDictionary *response;
    NSDictionary *parameters;
    NSString *peripheralUUIDString = [peripheral.identifier UUIDString];
    NSString *PeripheralName = [peripheral name] ? [peripheral name] : @"";
    if(!error)
    {
        NSString *RSSI = [NSString stringWithFormat:@"%@",[peripheral RSSI]];
        parameters = @{kPeripheralUUID:peripheralUUIDString,
                       kPeripheralName:PeripheralName,
                       kRSSIkey:RSSI};
        response = @{kResult:kGetRSSI,
                     kParams:parameters};
        [self sendResponse:response];
        return;
    }
    parameters = @{kPeripheralUUID:peripheralUUIDString,
                   kPeripheralName:PeripheralName};
    NSString *errorMessage = error.localizedDescription;
    response = @{kResult:kGetRSSI,
                 kParams:parameters,
                 kError:@{kCode:kError32603,kMessageField:errorMessage}};
    
    [self sendResponse:response];
}


#pragma mark - Request Call Handlers For Central Methods

- (void)configure:(NSDictionary *)request
{
    _availableDevices = [[NSMutableArray alloc] init];
    _connectedPeripheralsCollection = [[NSMutableDictionary alloc] init];
    _previousRequests = [NSMutableArray new];
    
    @try {
        NSDictionary *parameters = [request valueForKey:kParams];
        
        if(parameters != nil && [parameters valueForKey:kShowPowerAlert]) {
            NSMutableDictionary *options = [NSMutableDictionary new];
            
            NSString *identiferValue  = [parameters valueForKey:kIdentifierKey];
            if(identiferValue) {
                [options setObject:identiferValue forKey:CBCentralManagerOptionRestoreIdentifierKey];
            }
            
            BOOL showPwrAlert = [[parameters valueForKey:kShowPowerAlert] boolValue];
            if(showPwrAlert) {
                [options setObject:[NSNumber numberWithBool:showPwrAlert] forKey:CBCentralManagerOptionShowPowerAlertKey];
            }
            
            dispatch_queue_t centralQueue = dispatch_queue_create("org.gatt-ip.cbqueue", DISPATCH_QUEUE_SERIAL);
            self.centralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                                       queue:centralQueue
                                                                     options:nil];
            
            self.centralManager.delegate = self;
            [self sendResponse:@{kResult:kConfigure}];
        } else {
            [self invalidParameters:kConfigure];
        }
    }
    @catch (NSException *exception) {
        NSDictionary *parameters = @{kCode:kError32008};
        [self sendResponse:@{kResult:kConfigure, kError:parameters}];
    }
}

- (void)connect:(NSDictionary *)request
{
    if(![self isPoweredOn])
    {
        [self sendReasonForFailedCall];
        return;
    }
    
    NSDictionary *parameters = [request valueForKey:kParams];
    if(parameters != nil && [[parameters valueForKey:kPeripheralUUID] length] != 0) {
        NSString *UUIDStringOfPeripheralToConnect = [parameters valueForKey:kPeripheralUUID];
        
        NSDictionary *connectionOptions = @{CBConnectPeripheralOptionNotifyOnConnectionKey:[NSNumber numberWithBool:[[parameters valueForKey:kNotifyOnConnection] boolValue]],
                                            CBConnectPeripheralOptionNotifyOnDisconnectionKey:[NSNumber numberWithBool:[[parameters valueForKey:kNotifyOnDisconnection] boolValue]],
                                            CBConnectPeripheralOptionNotifyOnNotificationKey:[NSNumber numberWithBool:[[parameters valueForKey:kNotifyOnNotification] boolValue]]};
        for (CBPeripheral *peripheral in  _availableDevices)
        {
            NSString *UUIDStringOfPeripheral = [peripheral.identifier UUIDString];
            if ([UUIDStringOfPeripheralToConnect isEqualToString:UUIDStringOfPeripheral])
            {
                [self.centralManager connectPeripheral:peripheral options:connectionOptions];
                return;
            }
        }
        
        [self sendCharacteristicNotFoundErrorMessage];
    } else {
        [self invalidParameters:kConnect];
    }
}

- (void)disconnect:(NSDictionary *)request
{
    
    if(![self isPoweredOn])
    {
        [self sendReasonForFailedCall];
        return;
    }
    NSDictionary *parameters = [request valueForKey:kParams];
    if(parameters != nil) {
        NSString *UUIDStringOfPeripheralToDisconnect = [parameters valueForKey:kPeripheralUUID];
        for (NSString *peripheralUUIDString in  _connectedPeripheralsCollection)
        {
            CBPeripheral  *peripheral = [_connectedPeripheralsCollection objectForKey:peripheralUUIDString];
            NSUUID *peripheralIdentifier = [peripheral identifier];
            NSString *UUIDStringOfPeripheral = [peripheralIdentifier UUIDString];
            if ([UUIDStringOfPeripheralToDisconnect isEqualToString:UUIDStringOfPeripheral])
            {
                [self.centralManager cancelPeripheralConnection:peripheral];
                return;
            }
        }
        [self sendCharacteristicNotFoundErrorMessage];
    } else {
        [self invalidParameters:kDisconnect];
    }
}

- (void)getPerhipheralsWithServices:(NSDictionary *)request
{
    if(![self isPoweredOn])
    {
        [self sendReasonForFailedCall];
        return;
    }
    
    NSMutableDictionary *response = [[NSMutableDictionary alloc]init];
    //extract the list of service UUID strings
    NSDictionary *parameters = [request valueForKey:kParams];
    if(parameters != nil) {
        NSArray *listOfServiceUUIDStrings = [parameters objectForKey:kServiceUUIDs];
        if(listOfServiceUUIDStrings.count == 0)
        {
            [self sendNoServiceSpecified];
            return;
        }
        //construct the array of CBUUID Objects from the UUIDS given
        NSArray *listOfServiceCBUUIDs = [Util listOfServiceCBUUIDObjectsFrom:listOfServiceUUIDStrings];
        
        //get the list of peripherals(actual CBPeripheral objects) with those services
        NSArray *listOfPeripherals = [self.centralManager retrieveConnectedPeripheralsWithServices:listOfServiceCBUUIDs];
        
        //construct the response.
        [response setObject:kResult forKey:kGetPerhipheralsWithServices];
        NSMutableDictionary *peripheralsDictionary = [NSMutableDictionary new];
        NSDictionary *peripheralDict ;
        for (NSInteger itr = 0; itr < listOfPeripherals.count ; itr ++)
        {
            CBPeripheral *peripheral = [listOfPeripherals objectAtIndex:itr];
            NSString *peripheralState = [Util peripheralStateStringFromPeripheralState:peripheral.state];
            NSString *peripheralUUIDString = [Util peripheralUUIDStringFromPeripheral:peripheral];
            peripheralDict = @{kStateField:peripheralState,kPeripheralUUID:peripheralUUIDString};
            NSString *index = [NSString stringWithFormat:@"%ld",(long)itr];
            [peripheralsDictionary setObject:peripheralDict forKey:index];
        }
        //set the key/value pair key is the string peripherals and value peripherals dictionary
        [response setObject:peripheralDict forKey:kPeripherals];
        [self sendResponse:response];
    } else {
        [self invalidParameters:kGetPerhipheralsWithServices];
    }
}

- (void)getPerhipheralsWithIdentifiers:(NSDictionary *)request
{
    if(![self isPoweredOn])
    {
        [self sendReasonForFailedCall];
        return;
    }
    
    NSMutableDictionary *response = [[NSMutableDictionary alloc]init];
    //extract the list of peripheral UUID strings
    NSDictionary *parameters = [request valueForKey:kParams];
    if(parameters != nil ) {
        NSArray *listOfPeripheralUUIDStrings = [parameters objectForKey:kPeripheralUUIDs];
        if(!listOfPeripheralUUIDStrings)
        {
            [self sendNoPeripheralsSpecified];
            return;
        }
        //construct the array of NSUUID Objects from the UUIDS given
        NSMutableArray *listOfPeriheralNSUUIDs = [[NSMutableArray alloc]init];
        for (NSString *peripheralUUIDString in listOfPeripheralUUIDStrings)
        {
            NSUUID *aPeripheralUUID = [[NSUUID alloc]initWithUUIDString:peripheralUUIDString] ;
            [listOfPeriheralNSUUIDs addObject:aPeripheralUUID];
        }
        //get the list of peripherals(actual CBPeripheral objects) with those services
        NSArray *listOfPeripherals = [self.centralManager retrievePeripheralsWithIdentifiers:listOfPeriheralNSUUIDs];
        //construct the response.
        [response setObject:kResult forKey:kGetPerhipheralsWithIdentifiers];
        NSMutableDictionary *peripheralsDictionary = [NSMutableDictionary new];
        NSDictionary *peripheralDict;
        for (NSInteger itr = 0; itr < listOfPeripherals.count ; itr ++)
        {
            CBPeripheral *peripheral = [listOfPeripherals objectAtIndex:itr];
            NSString *peripheralState = [Util peripheralStateStringFromPeripheralState:peripheral.state];
            NSString *peripheralUUIDString = [Util peripheralUUIDStringFromPeripheral:peripheral];
            peripheralDict = @{kStateField:peripheralState,kPeripheralUUID:peripheralUUIDString};
            NSNumber *index = [NSNumber numberWithLong:itr];
            [peripheralsDictionary setObject:peripheralDict forKey:index];
        }
        //set the key/value pair key= peripherals and value peripherals dictionary
        [response setObject:peripheralDict forKey:kPeripherals];
        [self sendResponse:response];
    } else {
        [self invalidParameters:kGetPerhipheralsWithIdentifiers];
    }
}

- (void)scanForPeripherals:(NSDictionary *)request
{
    if(![self isPoweredOn])
    {
        [self sendReasonForFailedCall];
        return;
    }
    
    NSLog(@"scan for peripheral");
    if(request != nil) {
        if (isScanning) {
            [self.centralManager stopScan];
            requestDict = [NSDictionary dictionaryWithDictionary:request];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                isScanning = NO;
                [self scanForPeripherals:requestDict];
            });
        } else {
            requestDict = [NSDictionary dictionaryWithDictionary:request];
            NSDictionary *parameters = [request valueForKey:kParams];
            
            if(parameters != nil ) {
                NSNumber *duplicatesOnOffKey = [NSNumber numberWithBool:[[parameters valueForKey:kScanOptionAllowDuplicatesKey] boolValue]];
                
                NSArray *listOfOptionsUUIDStrings = [parameters objectForKey:kScanOptionSolicitedServiceUUIDs];
                NSArray *listOfServiceCBBUIDForOptions = [Util listOfServiceCBUUIDObjectsFrom:listOfOptionsUUIDStrings];
                
                //construct the options dictionary
                NSMutableDictionary *options = [NSMutableDictionary new];
                if(listOfServiceCBBUIDForOptions) {
                    [options setObject:listOfServiceCBBUIDForOptions forKey:kScanOptionSolicitedServiceUUIDs];
                }
                [options setObject:duplicatesOnOffKey forKey:kScanOptionAllowDuplicatesKey];
                //get list of service UUID strings
                NSArray *listOfServiceUUIDStrings = [parameters objectForKey:kServiceUUIDs];
                //construct the array of CBUUID Objects from the UUIDS given
                NSArray *listOfServiceCBUUIDs = [Util listOfServiceCBUUIDObjectsFrom:listOfServiceUUIDStrings];
                
                [self.centralManager scanForPeripheralsWithServices:listOfServiceCBUUIDs options:options];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [self scanForPeripherals:requestDict];
                });
                
                isScanning = YES;
            } else {
                [self invalidParameters:kScanForPeripherals];
            }
        }
    }
}

- (void)stopScanning:(NSDictionary *)request
{
    requestDict = nil;
    
    if([self isPoweredOn])
    {
        [self.centralManager stopScan];
    } else
    {
        [self sendReasonForFailedCall];
    }
}

- (void)getCentralState:(NSDictionary *)request
{
    NSString *stateOfCentral = [Util centralStateStringFromCentralState:self.centralManager.state];
    NSDictionary *response = @{kResult:kCentralState,
                               kStateField:stateOfCentral};
    
    [self sendResponse:response];
}

- (void)getConnectedPeripherals:(NSDictionary *)request
{
    NSMutableDictionary *response =  [NSMutableDictionary new];
    NSInteger index = 0;
    NSMutableDictionary *peripheralsDictionary = [NSMutableDictionary new];
    NSDictionary *peripheralDict;
    for (CBPeripheral *peripheral in _connectedPeripheralsCollection)
    {
        NSString *peripheralState = [Util peripheralStateStringFromPeripheralState:peripheral.state];
        NSString *peripheralUUIDString = [Util peripheralUUIDStringFromPeripheral:peripheral];
        peripheralDict = @{kStateField:peripheralState,kPeripheralUUID:peripheralUUIDString};
        NSNumber *indexNumber = [NSNumber numberWithLong:index];
        [peripheralsDictionary setObject:peripheralDict forKey:indexNumber];
        index +=1;
    }
    [response setObject:peripheralsDictionary forKey:kPeripherals];
}

#pragma mark - Request Call Handlers For Peripheral Methdos

- (void)getServices:(NSDictionary *)request
{
    NSDictionary *parameters = [request objectForKey:kParams];
    if(parameters != nil && [[parameters valueForKey:kPeripheralUUID] length] != 0) {
        NSString *peripheralUUIDString = [parameters valueForKey:kPeripheralUUID];
        NSUUID *peripheralIdentifier = [[NSUUID alloc]initWithUUIDString:peripheralUUIDString];
        
        //find the peripheral in the list of connected peripherals we maintain
        CBPeripheral *requestedPeripheral = [Util peripheralIn:_connectedPeripheralsCollection withNSUUID:peripheralIdentifier];
        if(!requestedPeripheral)
        {
            [self sendPeripheralNotFoundErrorMessage];
            return;
        }
        //get the list of CBUUIDS for the list of services to be searched for
        NSArray *serviceUUIDStrings = [parameters objectForKey:kServiceUUIDs];
        NSArray *serviceCBUUIDs = [Util listOfServiceCBUUIDObjectsFrom:serviceUUIDStrings];
        
        //make the CB call on the service to search for the services
        [requestedPeripheral discoverServices:serviceCBUUIDs];
    } else {
        [self invalidParameters:kGetServices];
    }
}

- (void)getIncludedServices:(NSDictionary *)request
{
    NSDictionary *parameters = [request objectForKey:kParams];
    if(parameters != nil && [[parameters valueForKey:kServiceUUID] length] != 0) {
        //find the service  in which the search for the included services is going to happen and the peipheral to search in
        NSString *serviceUUIDString = [parameters valueForKey:kServiceUUID];
        CBUUID *serviceUUID = [CBUUID UUIDWithString:serviceUUIDString];
        NSDictionary   *requestedPeripheralAndService = [Util serviceIn:_connectedPeripheralsCollection withCBUUID:serviceUUID];
        CBPeripheral *requestedPeripheral = [requestedPeripheralAndService objectForKey:peripheralKey];
        if(!requestedPeripheral)
        {
            [self sendPeripheralNotFoundErrorMessage];
            return;
        }
        CBService *requestedService = [requestedPeripheralAndService objectForKey:serviceKey];
        if(!requestedService)
        {
            [self sendServiceNotFoundErrorMessage];
            return;
        }
        //get the list of CBUUIDs - array of included services to be searched for
        NSArray *includedServicesUUIDStrings = [parameters objectForKey:kIncludedServiceUUIDs];
        NSArray *includedServicesCBUUIDs = [Util listOfServiceCBUUIDObjectsFrom:includedServicesUUIDStrings];
        
        [requestedPeripheral discoverIncludedServices:includedServicesCBUUIDs forService:requestedService];
    } else {
        [self invalidParameters:kGetIncludedServices];
    }
}

- (void)getCharacteristics:(NSDictionary *)request
{
    NSDictionary *parameters = [request objectForKey:kParams];
    if(parameters != nil && [[parameters valueForKey:kServiceUUID] length] != 0) {
        //find the service  in which the search for the included services is going to happen and the peipheral to search in
        NSString *serviceUUIDString = [parameters valueForKey:kServiceUUID];
        sCBUUID = serviceUUIDString;
        CBUUID *serviceUUID = [CBUUID UUIDWithString:serviceUUIDString];
        NSDictionary   *requestedPeripheralAndService = [Util serviceIn:_connectedPeripheralsCollection withCBUUID:serviceUUID];
        CBPeripheral *requestedPeripheral = [requestedPeripheralAndService objectForKey:peripheralKey];
        if(!requestedPeripheral)
        {
            [self sendPeripheralNotFoundErrorMessage];
            return;
        }
        CBService *requestedService = [requestedPeripheralAndService objectForKey:serviceKey];
        if(!requestedService)
        {
            [self sendServiceNotFoundErrorMessage];
            return;
        }
        NSArray *listOfCharacteristicUUIDStrings = [parameters objectForKey:kCharacteristicUUIDs];
        NSArray *listOfCharacteristicCBUUIDs = [Util listOfServiceCBUUIDObjectsFrom:listOfCharacteristicUUIDStrings];
        
        [requestedPeripheral discoverCharacteristics:listOfCharacteristicCBUUIDs forService:requestedService];
    } else {
        [self invalidParameters:kGetCharacteristics];
    }
}

- (void)getDescriptors:(NSDictionary *)request
{
    NSDictionary *parameters = [request objectForKey:kParams];
    if(parameters != nil && [[parameters objectForKey:kCharacteristicUUID] length] != 0) {
        NSString *characteristicsUUIDString = [parameters objectForKey:kCharacteristicUUID];
        CBUUID *characteristicsUUID = [CBUUID UUIDWithString:characteristicsUUIDString];
        NSDictionary *peripheralAndCharacteristic = [Util characteristicIn:_connectedPeripheralsCollection withCBUUID:characteristicsUUID];
        CBCharacteristic  *requestedCharacteristic = [peripheralAndCharacteristic objectForKey:characteristicKey];
        if(!requestedCharacteristic)
        {
            [self sendCharacteristicNotFoundErrorMessage ];
            return;
        }
        CBPeripheral *requestedPeripheral = [peripheralAndCharacteristic objectForKey:peripheralKey];
        
        [requestedPeripheral discoverDescriptorsForCharacteristic:requestedCharacteristic];
    } else {
        [self invalidParameters:kGetDescriptors];
    }
}

- (void)getCharacteristicValue:(NSDictionary *)request
{
    NSDictionary *parameters = [request objectForKey:kParams];
    if(parameters != nil && [[parameters objectForKey:kCharacteristicUUID] length] != 0) {
        NSString *characteristicsUUIDString = [parameters objectForKey:kCharacteristicUUID];
        CBUUID *characteristicsUUID = [CBUUID UUIDWithString:characteristicsUUIDString];
        NSDictionary *peripheralAndCharacteristic = [Util characteristicIn:_connectedPeripheralsCollection withCBUUID:characteristicsUUID];
        CBCharacteristic  *requestedCharacteristic = [peripheralAndCharacteristic objectForKey:characteristicKey];
        if(!requestedCharacteristic)
        {
            [self sendCharacteristicNotFoundErrorMessage ];
            return;
        }
        CBPeripheral *requestedPeripheral = [peripheralAndCharacteristic objectForKey:peripheralKey];
        
        [requestedPeripheral readValueForCharacteristic:requestedCharacteristic];
    } else {
        [self invalidParameters:kGetCharacteristicValue];
    }
}

- (void)writeCharacteristicValue:(NSDictionary *)request
{
    NSDictionary *parameters = [request objectForKey:kParams];
    if(parameters != nil && [[parameters objectForKey:kCharacteristicUUID] length] != 0 && [[parameters valueForKey:kValue] length] != 0) {
        NSString *characteristicsUUIDString = [parameters objectForKey:kCharacteristicUUID];
        CBUUID *characteristicsUUID = [CBUUID UUIDWithString:characteristicsUUIDString];
        NSDictionary *peripheralAndCharacteristic = [Util characteristicIn:_connectedPeripheralsCollection withCBUUID:characteristicsUUID];
        CBCharacteristic  *requestedCharacteristic = [peripheralAndCharacteristic objectForKey:characteristicKey];
        if(!requestedCharacteristic)
        {
            [self sendCharacteristicNotFoundErrorMessage ];
            return;
        }
        if([[parameters valueForKey:kValue] length]%2 != 0){
            NSDictionary *response;
            NSString *errorMessage = @"The value's length is invalid.";
            parameters = @{kCharacteristicUUID:characteristicsUUIDString};
            response = @{kResult:kGetCharacteristicValue,
                     kParams:parameters,
                     kError:@{kCode:kError32603,kMessageField:errorMessage}};
            [self sendResponse:response];
            return;
        }
        CBPeripheral *requestedPeripheral = [peripheralAndCharacteristic objectForKey:peripheralKey];
        CBCharacteristicWriteType writeType = [Util writeTypeForCharacteristicGiven:[parameters valueForKey:kWriteType]];
        
        NSData *dataToWrite = [Util hexToNSData:[parameters valueForKey:kValue]];
        
        [requestedPeripheral writeValue:dataToWrite forCharacteristic:requestedCharacteristic type:writeType];
    } else {
        [self invalidParameters:kWriteCharacteristicValue];
    }
}

- (void)getDescriptorValue:(NSDictionary *)request
{
    NSDictionary *parameters = [request objectForKey:kParams];
    if(parameters != nil && [[parameters objectForKey:kDescriptorUUID] length] != 0) {
        NSString *descriptorUUIDString = [parameters objectForKey:kDescriptorUUID];
        CBUUID *DescriptorUUID = [CBUUID UUIDWithString:descriptorUUIDString];
        NSDictionary *descriptorAndCharacteristic = [Util descriptorIn:_connectedPeripheralsCollection withCBUUID:DescriptorUUID];
        CBDescriptor *requestedDescriptor = [descriptorAndCharacteristic objectForKey:descriptorKey];
        if(!requestedDescriptor)
        {
            [self sendDescriptorNotFoundErrorMessage];
            return;
        }
        CBPeripheral *requestedPeripheral = [descriptorAndCharacteristic objectForKey:peripheralKey];
        
        [requestedPeripheral readValueForDescriptor:requestedDescriptor];
    } else {
        [self invalidParameters:kGetDescriptorValue];
    }
}

- (void)writeDescriptorValue:(NSDictionary *)request
{
    NSDictionary *parameters = [request objectForKey:kParams];
    if(parameters != nil && [[parameters objectForKey:descriptorKey] length] != 0) {
        NSString *descriptorUUIDString = [parameters objectForKey:descriptorKey];
        CBUUID *DescriptorUUID = [CBUUID UUIDWithString:descriptorUUIDString];
        NSDictionary *descriptorAndCharacteristic = [Util descriptorIn:_connectedPeripheralsCollection withCBUUID:DescriptorUUID];
        CBDescriptor *requestedDescriptor = [descriptorAndCharacteristic objectForKey:kDescriptorUUID];
        if(!requestedDescriptor)
        {
            [self sendDescriptorNotFoundErrorMessage];
            return;
        }
        CBPeripheral *requestedPeripheral = [descriptorAndCharacteristic objectForKey:peripheralKey];
        
        NSData *dataToWrite = [Util hexToNSData:[parameters valueForKey:kValue]];
        [requestedPeripheral writeValue:dataToWrite forDescriptor:requestedDescriptor];
    } else {
        [self invalidParameters:kWriteDescriptorValue];
    }
}

- (void)setValueNotification:(NSDictionary *)request
{
    NSDictionary *parameters = [request objectForKey:kParams];
    if(parameters != nil && [[parameters objectForKey:kCharacteristicUUID] length] != 0 && [parameters objectForKey:kValue] ) {
        NSString *characteristicsUUIDString = [parameters objectForKey:kCharacteristicUUID];
        CBUUID *characteristicsUUID = [CBUUID UUIDWithString:characteristicsUUIDString];
        BOOL subscribe = [[parameters objectForKey:kValue] boolValue];
        NSDictionary *requstedCharacteristicAndPeipheral = [Util characteristicIn:_connectedPeripheralsCollection withCBUUID:characteristicsUUID];
        CBCharacteristic *requstedCharacteristc = [requstedCharacteristicAndPeipheral objectForKey:characteristicKey];
        if(!requstedCharacteristc )
        {
            [self sendCharacteristicNotFoundErrorMessage];
            return;
        }
        CBPeripheral *requestedPeripheral  = [requstedCharacteristicAndPeipheral objectForKey:peripheralKey];
        
        [requestedPeripheral  setNotifyValue:subscribe forCharacteristic:requstedCharacteristc];
    } else {
        [self invalidParameters:kSetValueNotification];
    }
}

- (void)getPeripheralState:(NSDictionary *)request
{
    NSDictionary *parameters =[request objectForKey:kParams];
    if(parameters != nil && [[parameters objectForKey:kPeripheralUUID] length] != 0) {
        NSString *peripheralUUIDString = [parameters objectForKey:kPeripheralUUID];
        NSUUID *peripheralIdentifier = [[NSUUID alloc]initWithUUIDString:peripheralUUIDString];
        
        //find the peripheral in the list of connected peripherals we maintain
        CBPeripheral *requestedPeripheral = [Util peripheralIn:_connectedPeripheralsCollection withNSUUID:peripheralIdentifier];
        if(!requestedPeripheral)
        {
            [self sendPeripheralNotFoundErrorMessage];
            return;
        }
        NSString *peripheralState = [Util peripheralStateStringFromPeripheralState:requestedPeripheral.state];
        NSDictionary *response = @{kStateField:peripheralState,
                                   kResult:kGetPeripheralState};
        [self sendResponse:response];
    } else {
        [self invalidParameters:kGetPeripheralState];
    }
}

- (void)getRSSI:(NSDictionary *)request
{
    NSDictionary *parameters =[request objectForKey:kParams];
    if(parameters != nil && [[parameters objectForKey:kPeripheralUUID] length] != 0) {
        NSString *peripheralUUIDString = [parameters objectForKey:kPeripheralUUID];
        NSUUID *peripheralIdentifier = [[NSUUID alloc]initWithUUIDString:peripheralUUIDString];
        
        CBPeripheral *requestedPeripheral = [Util peripheralIn:_connectedPeripheralsCollection withNSUUID:peripheralIdentifier];
        if(!requestedPeripheral)
        {
            [self sendPeripheralNotFoundErrorMessage];
            return;
        }
        [requestedPeripheral readRSSI];
    } else {
        [self invalidParameters:kGetRSSI];
    }
}

#pragma mark - Reponse sender
/**
 *  Uses the given constructed response in the form of a dictionary
 *  adds jsonrpcVersion key/Value converts the kResulting dictionary
 *  to data and sends it to the delegate
 *  @param responseDictionary constructed Response based on the users request
 */
- (void)sendResponse:(NSDictionary *)responseDictionary
{
    [self handleLoggingRequestAndResponse:responseDictionary];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GotNewMessage" object: nil];
    NSMutableDictionary *kkResultDict = [NSMutableDictionary dictionary];
    [kkResultDict setValue:kJsonrpcVersion forKey:kJsonrpc];
    [kkResultDict addEntriesFromDictionary:responseDictionary];
    if(!_delegate)
    {
        return;
    }
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:kkResultDict
                                                       options:kNilOptions
                                                         error:&error];
    if (error)
    {
        NSDictionary *respDict = @{kError: @{kCode:kParseError, kMessageField : error.localizedDescription}};
        jsonData = [NSJSONSerialization dataWithJSONObject:respDict options:kNilOptions error:&error];
        if(!error)
        {
            [_delegate response:jsonData];
            return;
        }
        [_delegate response:nil ];
        return;
    }
    
    [_delegate response:jsonData ];
}

#pragma mark - helper
- (BOOL)isPoweredOn
{
    if(self.centralManager.state == CBCentralManagerStatePoweredOn)
    {
        return YES;
    }
    return NO;
}

- (void)sendReasonForFailedCall
{
    NSDictionary* responseDictionary = @{ kError: @{kCode:kError32005}};
    [self sendResponse:responseDictionary];
}

- (void)sendPeripheralNotFoundErrorMessage
{
    NSMutableDictionary *response = [NSMutableDictionary new];
    [response setObject:kJsonrpcVersion forKey:kJsonrpc];
    NSDictionary *errorResponse = @{kError:@{kCode:kError32001}};
    [response addEntriesFromDictionary:errorResponse];
    [self sendResponse:response];
}

- (void)sendServiceNotFoundErrorMessage
{
    NSMutableDictionary *response = [NSMutableDictionary new];
    [response setObject:kJsonrpcVersion forKey:kJsonrpc];
    NSDictionary *errorResponse = @{kError:@{kCode:kError32002}};
    [response addEntriesFromDictionary:errorResponse];
    [self sendResponse:response];
}

- (void)sendCharacteristicNotFoundErrorMessage
{
    NSMutableDictionary *response = [NSMutableDictionary new];
    [response setObject:kJsonrpcVersion forKey:kJsonrpc];
    NSDictionary *errorResponse = @{kError:@{kCode:kError32003}};
    [response addEntriesFromDictionary:errorResponse];
    [self sendResponse:response];
}

- (void)sendDescriptorNotFoundErrorMessage
{
    NSMutableDictionary *response = [NSMutableDictionary new];
    [response setObject:kJsonrpcVersion forKey:kJsonrpc];
    NSDictionary *errorResponse = @{kError:@{kCode:kError32004}};
    [response addEntriesFromDictionary:errorResponse];
    [self sendResponse:response];
}

- (void)sendNoServiceSpecified
{
    NSMutableDictionary *response = [NSMutableDictionary new];
    [response setObject:kJsonrpcVersion forKey:kJsonrpc];
    NSDictionary *errorResponse = @{kError:@{kCode:kError32006}};
    [response addEntriesFromDictionary:errorResponse];
    [self sendResponse:response];
}

- (void)sendNoPeripheralsSpecified
{
    NSMutableDictionary *response = [NSMutableDictionary new];
    [response setObject:kJsonrpcVersion forKey:kJsonrpc];
    NSDictionary *errorResponse = @{kError:@{kCode:kError32007}};
    [response addEntriesFromDictionary:errorResponse];
    [self sendResponse:response];
}

-(void)invalidParameters:(NSString *)method
{
    NSMutableDictionary *response = [NSMutableDictionary new];
    [response setObject:kJsonrpcVersion forKey:kJsonrpc];
    [response setObject:method forKey:kResult];
    NSDictionary *errorResponse = @{kCode:kInvalidParams};
    [response setObject:errorResponse forKey:kError];
    [self sendResponse:response];
    
}

-(void)dealloc {
    for (NSString *peripheralUUIDString in _connectedPeripheralsCollection){
        CBPeripheral  *peripheral = [_connectedPeripheralsCollection objectForKey:peripheralUUIDString];
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
    self.centralManager.delegate = nil;
    self.centralManager = nil;
}

#pragma mark - Helpers
/**
 *  Converts the hex string fields to the
 *
 *  @param input (the input Dictionary from which the human Readable Dictionary is going to be formed from
 *
 *  @return the dictionary which is converted to the human Readable Format.
 */
- (NSMutableDictionary *)convertToHumanReadableFormat:(NSDictionary *)input
{
    NSMutableDictionary *outputRespnose = [NSMutableDictionary new];
    NSArray *allKeysForResponse = [input allKeys];
    NSString *humanReadableKey ;
    //convert all the keys(keys that don't need conversion will just stay the same since they are setup in that way in the humanReadableFormatFromHex dic
    //we also convert the values that need conversion while we convert the keys.
    for (NSString *key in allKeysForResponse)
    {
        id value = [input objectForKey:key];
        humanReadableKey = [Util humanReadableFormatFromHex:key];
        if([value isKindOfClass:[NSString class]])
        {
            NSString *humanReadableValue = value;
            humanReadableValue =  [Util humanReadableFormatFromHex:value];
            [outputRespnose setObject:humanReadableValue forKey:humanReadableKey];
        }
        else if([value isKindOfClass:[NSDictionary class]])
        {
            NSDictionary *humanReadableValue ;
            humanReadableValue = [self convertToHumanReadableFormat:value];
            [outputRespnose setObject:humanReadableValue forKey:humanReadableKey];
        }
        else
        {
            NSDictionary *humanReadableValue  = value;
            [outputRespnose setObject:humanReadableValue forKey:humanReadableKey];
        }
    }
    return outputRespnose;
}

- (void)handleLoggingRequestAndResponse:(NSDictionary *)input
{
    if(_previousRequests.count > MAX_NUMBER_OF_REQUESTS)
    {
        NSIndexSet *setOfIndeciesToRemove = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,floor(MAX_NUMBER_OF_REQUESTS/4.0f))];
        [_previousRequests removeObjectsAtIndexes:setOfIndeciesToRemove];
    }
    [_previousRequests addObject:[self convertToHumanReadableFormat:input]];
}

- (NSArray *)listOFResponseAndRequests
{
    return _previousRequests;
}

@end

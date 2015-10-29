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



@interface GATTIP () <CBCentralManagerDelegate,CBPeripheralDelegate>

@property CBCentralManager *centralManager;
@property NSMutableArray *availableDevices;
@property NSMutableDictionary *connectedPeripheralsCollection;
@property NSMutableArray *requestIDs;

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
            //[self getPerhipheralsWithServices:request];
        }
        else if ([[request valueForKey:kMethod] isEqualToString:kGetPerhipheralsWithIdentifiers])
        {
            //[self getPerhipheralsWithIdentifiers:request];
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
    NSData *peripheralData = [advertisementData objectForKey:@"kCBAdvDataManufacturerData"];
    if(peripheralData)
    {
        NSString *peripheralDataAsHex = [Util nsDataToHex:peripheralData];
        [advData appendString:[NSString stringWithFormat:@"%02x",(unsigned int)[peripheralData length]+1]];
        [advData appendString:kManufacturerSpecificData];
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
                serviceType = kServiceData16bitUUID;
                [uuid appendString:[Util reverseServiceUUID:serviceUUID]];
            } else if([serviceUUID length] == 8) {
                length += 4;
                serviceType = kServiceData32bitUUID;
                serviceUUID = [serviceUUID stringByReplacingOccurrencesOfString:@"-" withString:@""];
                [uuid appendString:[Util reverseServiceUUID:serviceUUID]];
            } else if([serviceUUID length] == 36) {
                length += 16;
                serviceType = kServiceData128bitUUID;
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
        NSString *serviceUUIDString;
        for(CBUUID *service in kCBAdvertisementDataServiceDataDictionary) {
            serviceUUIDString = service.UUIDString;
        }
        if(serviceUUIDString) {
            NSString * servcieData = [mutatedkCBAdvertisementDataServiceDataDictionary valueForKey:serviceUUIDString];
            int dataLength = (int)[servcieData length]/2 + 3;
            [advData appendString:[[NSString stringWithFormat:@"%02x", dataLength] uppercaseString]];
            [advData appendString:kServiceData];
            [advData appendString:[[NSString stringWithFormat:@"%@%@",[Util reverseServiceUUID:serviceUUIDString],servcieData] uppercaseString]];
        }
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
    [advData appendString:kADFlags];
    [advData appendString:[NSString stringWithFormat:@"%02x",[kCBAdvertisementDataIsConnectableValue intValue]]];
    
    //--CBAdvertisementDataTxPowerLevelKey
    NSNumber *kCBAdvertisementDataTxPowerLevelKey = [advertisementData objectForKey:@"kCBAdvDataTxPowerLevel"];
    if(kCBAdvertisementDataTxPowerLevelKey)
    {
        NSString *powerKey = [kCBAdvertisementDataTxPowerLevelKey stringValue];
        [advData appendString:[NSString stringWithFormat:@"%02x",(unsigned int)[powerKey length]+1]];
        [advData appendString:kTxPowerLevel];
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
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{

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
    //TODO: additional fields in params to be documented
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
    //NSString *serviceUUIDString = [characteristic.service.UUID UUIDString];
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
    /*parameters = @{kCharacteristicUUID:characteristicUUIDString,
     kPeripheralUUID:peripheralUUIDString};
     NSString *errorMessage = error.localizedDescription;
     response = @{kResult:kGetDescriptors,
     kParams:parameters,
     kError:@{kCode:kError32603,kMessageField:errorMessage}};*/
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
    _requestIDs = [NSMutableArray new];

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
            [self invalidParameters:kConfigure requestId:NULL];
        }
    }
    @catch (NSException *exception) {
        NSDictionary *parameters = @{kCode:kError32008};
        [self sendResponse:@{kResult:kConfigure, kError:parameters}];
    }
}

- (void)connect:(NSDictionary *)request
{
    NSString *requestID = [self getRequestID:request];
    if(![self isPoweredOn])
    {
        [self sendReasonForFailedCall:kConnect requestId:requestID];
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
                [self requestID:requestID withPeripheralUUID:UUIDStringOfPeripheralToConnect inMethod:kConnect];
                [self.centralManager connectPeripheral:peripheral options:connectionOptions];
                return;
            }
        }
    } else {
        [self invalidParameters:kConnect requestId:requestID];
    }
}

- (void)disconnect:(NSDictionary *)request
{
    NSString *requestID = [self getRequestID:request];
    if(![self isPoweredOn])
    {
        [self sendReasonForFailedCall:kDisconnect requestId:requestID];
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
                [self requestID:requestID withPeripheralUUID:UUIDStringOfPeripheralToDisconnect inMethod:kDisconnect];
                [self.centralManager cancelPeripheralConnection:peripheral];
                return;
            }
        }
    } else {
        [self invalidParameters:kDisconnect requestId:requestID];
    }
}

- (void)scanForPeripherals:(NSDictionary *)request
{
    if(![self isPoweredOn])
    {
        [self sendReasonForFailedCall:kScanForPeripherals requestId:NULL];
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
                [self invalidParameters:kScanForPeripherals requestId:NULL];
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
        [self sendReasonForFailedCall:kStopScanning requestId:NULL];
    }
}

- (void)getCentralState:(NSDictionary *)request
{
    NSString *centralState = [Util centralStateStringFromCentralState:self.centralManager.state];
    NSDictionary *parameters = @{kState:centralState};
    NSDictionary *response = @{kParams:parameters,
                                   kResult:kCentralState};
    
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
    NSString *requestID = [self getRequestID:request];
    if(requestID)
        [response setValue:requestID forKey:kIdField];
    [response setObject:peripheralsDictionary forKey:kPeripherals];
    [response setValue:kGetConnectedPeripherals forKey:kResult];
}

#pragma mark - Request Call Handlers For Peripheral Methdos

- (void)getServices:(NSDictionary *)request
{
    NSString *requestID = [self getRequestID:request];
    NSDictionary *parameters = [request objectForKey:kParams];
    if(parameters != nil && [[parameters valueForKey:kPeripheralUUID] length] != 0) {
        NSString *peripheralUUIDString = [parameters valueForKey:kPeripheralUUID];
        NSUUID *peripheralIdentifier = [[NSUUID alloc]initWithUUIDString:peripheralUUIDString];
        
        //find the peripheral in the list of connected peripherals we maintain
        CBPeripheral *requestedPeripheral = [Util peripheralIn:_connectedPeripheralsCollection withNSUUID:peripheralIdentifier];
        if(!requestedPeripheral)
        {
            [self sendPeripheralNotFoundErrorMessage:kGetServices requestId:requestID];
            return;
        }
        //get the list of CBUUIDS for the list of services to be searched for
        NSArray *serviceUUIDStrings = [parameters objectForKey:kServiceUUIDs];
        NSArray *serviceCBUUIDs = [Util listOfServiceCBUUIDObjectsFrom:serviceUUIDStrings];
        [self requestID:requestID withPeripheralUUID:[[requestedPeripheral identifier] UUIDString] inMethod:kGetServices];
        //make the CB call on the service to search for the services
        [requestedPeripheral discoverServices:serviceCBUUIDs];
    } else {
        [self invalidParameters:kGetServices requestId:requestID];
    }
}

- (void)getIncludedServices:(NSDictionary *)request
{
    NSString *requestID = [self getRequestID:request];
    NSDictionary *parameters = [request objectForKey:kParams];
    if(parameters != nil && [[parameters valueForKey:kServiceUUID] length] != 0) {
        //find the service  in which the search for the included services is going to happen and the peipheral to search in
        NSString *serviceUUIDString = [parameters valueForKey:kServiceUUID];
        CBUUID *serviceUUID = [CBUUID UUIDWithString:serviceUUIDString];
        NSDictionary   *requestedPeripheralAndService = [Util serviceIn:_connectedPeripheralsCollection withCBUUID:serviceUUID];
        CBPeripheral *requestedPeripheral = [requestedPeripheralAndService objectForKey:peripheralKey];
        if(!requestedPeripheral)
        {
            [self sendPeripheralNotFoundErrorMessage:kGetIncludedServices requestId:requestID];
            return;
        }
        CBService *requestedService = [requestedPeripheralAndService objectForKey:serviceKey];
        if(!requestedService)
        {
            [self sendServiceNotFoundErrorMessage:kGetIncludedServices requestId:requestID];
            return;
        }
        //get the list of CBUUIDs - array of included services to be searched for
        NSArray *includedServicesUUIDStrings = [parameters objectForKey:kIncludedServiceUUIDs];
        NSArray *includedServicesCBUUIDs = [Util listOfServiceCBUUIDObjectsFrom:includedServicesUUIDStrings];
        [self requestID:requestID withPeripheralUUID:[[requestedPeripheral identifier] UUIDString] inMethod:kGetIncludedServices];
        [requestedPeripheral discoverIncludedServices:includedServicesCBUUIDs forService:requestedService];
    } else {
        [self invalidParameters:kGetIncludedServices requestId:requestID];
    }
}

- (void)getCharacteristics:(NSDictionary *)request
{
    NSString *requestID = [self getRequestID:request];
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
            [self sendPeripheralNotFoundErrorMessage:kGetCharacteristics requestId:requestID];
            return;
        }
        CBService *requestedService = [requestedPeripheralAndService objectForKey:serviceKey];
        if(!requestedService)
        {
            [self sendServiceNotFoundErrorMessage:kGetCharacteristics requestId:requestID];

            return;
        }
        NSArray *listOfCharacteristicUUIDStrings = [parameters objectForKey:kCharacteristicUUIDs];
        NSArray *listOfCharacteristicCBUUIDs = [Util listOfServiceCBUUIDObjectsFrom:listOfCharacteristicUUIDStrings];
        [self requestID:requestID withPeripheralUUID:[[requestedPeripheral identifier] UUIDString] inMethod:kGetCharacteristics];
        [requestedPeripheral discoverCharacteristics:listOfCharacteristicCBUUIDs forService:requestedService];
    } else {
        [self invalidParameters:kGetCharacteristics requestId:requestID];
    }
}

- (void)getDescriptors:(NSDictionary *)request
{
    NSString *requestID = [self getRequestID:request];
    NSDictionary *parameters = [request objectForKey:kParams];
    if(parameters != nil && [[parameters objectForKey:kCharacteristicUUID] length] != 0) {
        NSString *characteristicsUUIDString = [parameters objectForKey:kCharacteristicUUID];
        CBUUID *characteristicsUUID = [CBUUID UUIDWithString:characteristicsUUIDString];
        NSDictionary *peripheralAndCharacteristic = [Util characteristicIn:_connectedPeripheralsCollection withCBUUID:characteristicsUUID];
        CBCharacteristic  *requestedCharacteristic = [peripheralAndCharacteristic objectForKey:characteristicKey];
        if(!requestedCharacteristic)
        {
            [self sendCharacteristicNotFoundErrorMessage:kGetDescriptors requestId:requestID];
            return;
        }
        CBPeripheral *requestedPeripheral = [peripheralAndCharacteristic objectForKey:peripheralKey];
        [self requestID:requestID withPeripheralUUID:[[requestedPeripheral identifier] UUIDString] inMethod:kGetDescriptors];
        [requestedPeripheral discoverDescriptorsForCharacteristic:requestedCharacteristic];
    } else {
        [self invalidParameters:kGetDescriptors requestId:requestID];
    }
}

- (void)getCharacteristicValue:(NSDictionary *)request
{
    NSString *requestID = [self getRequestID:request];
    NSDictionary *parameters = [request objectForKey:kParams];
    if(parameters != nil && [[parameters objectForKey:kCharacteristicUUID] length] != 0) {
        NSString *characteristicsUUIDString = [parameters objectForKey:kCharacteristicUUID];
        CBUUID *characteristicsUUID = [CBUUID UUIDWithString:characteristicsUUIDString];
        NSDictionary *peripheralAndCharacteristic = [Util characteristicIn:_connectedPeripheralsCollection withCBUUID:characteristicsUUID];
        CBCharacteristic  *requestedCharacteristic = [peripheralAndCharacteristic objectForKey:characteristicKey];
        if(!requestedCharacteristic)
        {
            [self sendCharacteristicNotFoundErrorMessage:kGetCharacteristicValue requestId:requestID];
            return;
        }
        CBPeripheral *requestedPeripheral = [peripheralAndCharacteristic objectForKey:peripheralKey];
        [self requestID:requestID withPeripheralUUID:[[requestedPeripheral identifier] UUIDString] inMethod:kGetCharacteristicValue];
        [requestedPeripheral readValueForCharacteristic:requestedCharacteristic];
    } else {
        [self invalidParameters:kGetCharacteristicValue requestId:requestID];
    }
}

- (void)writeCharacteristicValue:(NSDictionary *)request
{
    NSString *requestID = [self getRequestID:request];
    NSDictionary *parameters = [request objectForKey:kParams];
    if(parameters != nil && [[parameters objectForKey:kCharacteristicUUID] length] != 0 && [[parameters valueForKey:kValue] length] != 0) {
        NSString *characteristicsUUIDString = [parameters objectForKey:kCharacteristicUUID];
        CBUUID *characteristicsUUID = [CBUUID UUIDWithString:characteristicsUUIDString];
        NSDictionary *peripheralAndCharacteristic = [Util characteristicIn:_connectedPeripheralsCollection withCBUUID:characteristicsUUID];
        CBCharacteristic  *requestedCharacteristic = [peripheralAndCharacteristic objectForKey:characteristicKey];
        if(!requestedCharacteristic)
        {
            [self sendCharacteristicNotFoundErrorMessage:kWriteCharacteristicValue requestId:requestID];
            return;
        }
        if([[parameters valueForKey:kValue] length]%2 != 0){
            NSMutableDictionary *response = [NSMutableDictionary new];
            NSString *errorMessage = @"The value's length is invalid.";
            parameters = @{kCharacteristicUUID:characteristicsUUIDString};
            NSDictionary *errorResponse = @{kCode:kError32603,kMessageField:errorMessage};
            [response setValue:kWriteCharacteristicValue forKey:kResult];
            [response setObject:parameters forKey:kParams];
            [response setObject:errorResponse forKey:kError];
            if(requestID)
                [response setValue:requestID forKey:kIdField];
              [self sendResponse:response];
            return;
        }
        CBPeripheral *requestedPeripheral = [peripheralAndCharacteristic objectForKey:peripheralKey];
        //TODO we neeed to handle writetype once we set the value for writetype on JS
        CBCharacteristicWriteType writeType = [Util writeTypeForCharacteristicGiven:[parameters valueForKey:kWriteType]];
        [self requestID:requestID withPeripheralUUID:[[requestedPeripheral identifier] UUIDString] inMethod:kWriteCharacteristicValue];
        NSData *dataToWrite = [Util hexToNSData:[parameters valueForKey:kValue]];
        
        [requestedPeripheral writeValue:dataToWrite forCharacteristic:requestedCharacteristic type:writeType];
    } else {
        [self invalidParameters:kWriteCharacteristicValue requestId:requestID];
    }
}

- (void)getDescriptorValue:(NSDictionary *)request
{
    NSString *requestID = [self getRequestID:request];
    NSDictionary *parameters = [request objectForKey:kParams];
    if(parameters != nil && [[parameters objectForKey:kDescriptorUUID] length] != 0) {
        NSString *descriptorUUIDString = [parameters objectForKey:kDescriptorUUID];
        CBUUID *DescriptorUUID = [CBUUID UUIDWithString:descriptorUUIDString];
        NSDictionary *descriptorAndCharacteristic = [Util descriptorIn:_connectedPeripheralsCollection withCBUUID:DescriptorUUID];
        CBDescriptor *requestedDescriptor = [descriptorAndCharacteristic objectForKey:descriptorKey];
        if(!requestedDescriptor)
        {
            [self sendDescriptorNotFoundErrorMessage:kGetDescriptorValue requestId:requestID];
            return;
        }
        CBPeripheral *requestedPeripheral = [descriptorAndCharacteristic objectForKey:peripheralKey];
        [self requestID:requestID withPeripheralUUID:[[requestedPeripheral identifier] UUIDString] inMethod:kGetDescriptorValue];
        [requestedPeripheral readValueForDescriptor:requestedDescriptor];
    } else {
        [self invalidParameters:kGetDescriptorValue requestId:requestID];
    }
}

- (void)writeDescriptorValue:(NSDictionary *)request
{
    NSString *requestID = [self getRequestID:request];
    NSDictionary *parameters = [request objectForKey:kParams];
    if(parameters != nil && [[parameters objectForKey:descriptorKey] length] != 0) {
        NSString *descriptorUUIDString = [parameters objectForKey:descriptorKey];
        CBUUID *DescriptorUUID = [CBUUID UUIDWithString:descriptorUUIDString];
        NSDictionary *descriptorAndCharacteristic = [Util descriptorIn:_connectedPeripheralsCollection withCBUUID:DescriptorUUID];
        CBDescriptor *requestedDescriptor = [descriptorAndCharacteristic objectForKey:kDescriptorUUID];
        if(!requestedDescriptor)
        {
            [self sendDescriptorNotFoundErrorMessage:kWriteDescriptorValue requestId:requestID];
            return;
        }
        CBPeripheral *requestedPeripheral = [descriptorAndCharacteristic objectForKey:peripheralKey];
        [self requestID:requestID withPeripheralUUID:[[requestedPeripheral identifier] UUIDString] inMethod:kWriteDescriptorValue];
        NSData *dataToWrite = [Util hexToNSData:[parameters valueForKey:kValue]];
        [requestedPeripheral writeValue:dataToWrite forDescriptor:requestedDescriptor];
    } else {
        [self invalidParameters:kWriteDescriptorValue requestId:requestID];
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
            [self sendCharacteristicNotFoundErrorMessage:kSetValueNotification requestId:NULL];
            return;
        }
        CBPeripheral *requestedPeripheral  = [requstedCharacteristicAndPeipheral objectForKey:peripheralKey];
        
        [requestedPeripheral  setNotifyValue:subscribe forCharacteristic:requstedCharacteristc];
    } else {
        [self invalidParameters:kSetValueNotification requestId:NULL];
    }
}

- (void)getPeripheralState:(NSDictionary *)request
{
    NSString *requestID = [self getRequestID:request];
    NSDictionary *parameters =[request objectForKey:kParams];
    if(parameters != nil && [[parameters objectForKey:kPeripheralUUID] length] != 0) {
        NSString *peripheralUUIDString = [parameters objectForKey:kPeripheralUUID];
        NSUUID *peripheralIdentifier = [[NSUUID alloc]initWithUUIDString:peripheralUUIDString];
        
        //find the peripheral in the list of connected peripherals we maintain
        CBPeripheral *requestedPeripheral = [Util peripheralIn:_connectedPeripheralsCollection withNSUUID:peripheralIdentifier];
        if(!requestedPeripheral)
        {
            [self sendPeripheralNotFoundErrorMessage:kGetPeripheralState requestId:requestID];
            return;
        }
        NSString *peripheralState = [Util peripheralStateStringFromPeripheralState:requestedPeripheral.state];
        NSMutableDictionary *response = [[NSMutableDictionary alloc] init];
        [response setValue:peripheralState forKey:kStateField];
        if(requestID)
            [response setValue:requestID forKey:kIdField];
        [response setValue:kGetPeripheralState forKey:kResult];
        [self sendResponse:response];
    } else {
        [self invalidParameters:kGetPeripheralState requestId:requestID];
    }
}

- (void)getRSSI:(NSDictionary *)request
{
    NSString *requestID = [self getRequestID:request];
    NSDictionary *parameters =[request objectForKey:kParams];
    if(parameters != nil && [[parameters objectForKey:kPeripheralUUID] length] != 0) {
        NSString *peripheralUUIDString = [parameters objectForKey:kPeripheralUUID];
        NSUUID *peripheralIdentifier = [[NSUUID alloc]initWithUUIDString:peripheralUUIDString];
        
        CBPeripheral *requestedPeripheral = [Util peripheralIn:_connectedPeripheralsCollection withNSUUID:peripheralIdentifier];
        if(!requestedPeripheral)
        {
            [self sendPeripheralNotFoundErrorMessage:kGetRSSI requestId:requestID];
            return;
        }
        [self requestID:requestID withPeripheralUUID:[[requestedPeripheral identifier] UUIDString] inMethod:kGetRSSI];
        [requestedPeripheral readRSSI];
    } else {
        [self invalidParameters:kGetRSSI requestId:requestID];
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
    NSMutableDictionary *kkResultDict = [NSMutableDictionary dictionary];
    [kkResultDict setValue:kJsonrpcVersion forKey:kJsonrpc];
    [kkResultDict addEntriesFromDictionary:responseDictionary];
    //sending request id's
    if([kkResultDict valueForKey:kResult]) {
        NSString *result = [kkResultDict valueForKey:kResult];
        for(int i = 0; i < [_requestIDs count]; i++) {
            NSDictionary *dict = [_requestIDs objectAtIndex:i];
            NSDictionary *idDict = [dict objectForKey:result];
            NSString *requestId = [[idDict allKeys] objectAtIndex:0];
            if([[[kkResultDict valueForKey:kParams] valueForKey:kPeripheralUUID] isEqualToString:[idDict valueForKey:requestId]]) {
                [kkResultDict setValue:requestId forKey:kIdField];
                [_requestIDs removeObjectAtIndex:i];
                break;
            }
        }
    }
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

- (void)sendReasonForFailedCall:(NSString *)method requestId:(NSString *)requestId
{
    
    NSMutableDictionary *response = [NSMutableDictionary new];
    [response setValue:method forKey:kResult];
    if(requestId)
        [response setValue:requestId forKey:kIdField];
    NSDictionary *errorResponse = @{kError:@{kCode:kError32005,kMessageField:@"Device not powered on."}};
    [response addEntriesFromDictionary:errorResponse];
    [self sendResponse:response];
    
}

- (void)sendPeripheralNotFoundErrorMessage:(NSString *)method requestId:(NSString *)requestId
{
    NSMutableDictionary *response = [NSMutableDictionary new];
    [response setValue:method forKey:kResult];
    if(requestId)
        [response setValue:requestId forKey:kIdField];
    NSDictionary *errorResponse = @{kError:@{kCode:kError32001,kMessageField:@"Peripheral not found."}};
    [response addEntriesFromDictionary:errorResponse];
    [self sendResponse:response];
}

- (void)sendServiceNotFoundErrorMessage:(NSString *)method requestId:(NSString *)requestId
{
    NSMutableDictionary *response = [NSMutableDictionary new];
    [response setValue:method forKey:kResult];
    if(requestId)
        [response setValue:requestId forKey:kIdField];
    NSDictionary *errorResponse = @{kError:@{kCode:kError32002,kMessageField:@"Service not found."}};
    [response addEntriesFromDictionary:errorResponse];
    [self sendResponse:response];
}


- (void)sendCharacteristicNotFoundErrorMessage:(NSString *)method requestId:(NSString *)requestId
{
    NSMutableDictionary *response = [NSMutableDictionary new];
    [response setValue:method forKey:kResult];
    if(requestId)
        [response setValue:requestId forKey:kIdField];
    NSDictionary *errorResponse = @{kError:@{kCode:kError32003,kMessageField:@"Characteristic not found."}};
    [response addEntriesFromDictionary:errorResponse];
    [self sendResponse:response];
}

- (void)sendDescriptorNotFoundErrorMessage:(NSString *)method requestId:(NSString *)requestId
{
    NSMutableDictionary *response = [NSMutableDictionary new];
    [response setValue:method forKey:kResult];
    if(requestId)
        [response setValue:requestId forKey:kIdField];
    NSDictionary *errorResponse = @{kError:@{kCode:kError32004,kMessageField:@"Specified Descriptor not found."}};
    [response addEntriesFromDictionary:errorResponse];
    [self sendResponse:response];
}

-(void)invalidParameters:(NSString *)method requestId:(NSString *)requestId
{
    NSMutableDictionary *response = [NSMutableDictionary new];
    [response setValue:method forKey:kResult];
    if(requestId) {
        [response setValue:requestId forKey:kIdField];
    }
    NSDictionary *errorResponse = @{kCode:kInvalidParams,kMessageField:@"Insufficient parameters."};
    [response setObject:errorResponse forKey:kError];
    [self sendResponse:response];
}

-(void)requestID:(NSString *)requestId withPeripheralUUID:(NSString *)peripheralUUID inMethod:(NSString *)method {
    if(requestId) {
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        [dict setValue:peripheralUUID forKey:requestId];
        NSDictionary *senderDict = @{method:dict};
        [_requestIDs addObject:senderDict];
    }
}

-(NSString *)getRequestID:(NSDictionary *)request {
    NSString *requestID = NULL;
    if([request valueForKey:kIdField])
        requestID = [request valueForKey:kIdField];
    return requestID;
}

-(void)dealloc {
    for (NSString *peripheralUUIDString in _connectedPeripheralsCollection){
        CBPeripheral  *peripheral = [_connectedPeripheralsCollection objectForKey:peripheralUUIDString];
        [self.centralManager cancelPeripheralConnection:peripheral];
    }
    self.centralManager.delegate = nil;
    self.centralManager = nil;
}



@end

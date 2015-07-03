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

#import <CoreBluetooth/CoreBluetooth.h>
#import "GATTIP.h"

//internal use(don't appear in the JSON objects)
static NSString * const peripheralKey = @"peripheral";//@"peripheral";
static NSString * const serviceKey = @"service";//@"service";
static NSString * const characteristicKey = @"characteristic";//@"characteristic";
static NSString * const descriptorKey = @"descriptor";//@"descriptor";

@interface Util : NSObject

+ (NSString *)peripheralStateStringFromPeripheralState:(CBPeripheralState )peripheralState;

+ (NSString *)centralStateStringFromCentralState:(CBCentralManagerState )centralState;

+ (NSString *)peripheralUUIDStringFromPeripheral:(CBPeripheral *)peripheral;

+ (NSArray *)listOfServiceCBUUIDObjectsFrom:(NSArray *)arrayOfServiceUUIDStrings;

+ (CBPeripheral *)peripheralIn:(NSMutableDictionary *)peripheralCollection  withNSUUID:(NSUUID *)peripheralIdentifier;

+ (NSDictionary *)serviceIn:(NSMutableDictionary *)peripheralCollection  withCBUUID:(CBUUID *)serviceUUID;

+ (NSDictionary *)characteristicIn:(NSMutableDictionary *)peripheralCollection  withCBUUID:(CBUUID *)kCharacteristicUUID;

+ (NSDictionary *)descriptorIn:(NSMutableDictionary *)peripheralCollection withCBUUID:(CBUUID *)descriptorUUID;

+ (NSArray *)listOfJsonServicesFrom:(NSArray *)arrayOfServices;

+ (NSArray *)listOfJsonCharacteristicsFrom:(NSArray *)arrayOfServices;

+ (NSArray *)listOfJsonDescriptorsFrom:(NSArray *)arrayOfServices;

+ (NSString*) nsDataToHex:(NSData*)data ;

+(NSString*)nsStringToHex:(NSString*)hex;

+ (NSMutableData *) hexToNSData: (NSString *) command;

+ (NSString *)stringDescriptorValueFrom:(CBDescriptor *)descriptor;

+ (CBCharacteristicWriteType )writeTypeForCharacteristicGiven:(NSString *)stringWriteType;

+ (NSString *)humanReadableFormatFromHex:(NSString *)hexString;

+ (NSArray *)listOfServiceUUIDStrings:(NSArray *)input;

/**
 *  Helps convert the Dictionary object for key  CBAdvertisementDataServiceDataKey in advertisment dictionary in
 *  the delegate method  - (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
 advertisementData:(NSDictionary *)advertisementData
 RSSI:(NSNumber *)RSSI
 ----- ALSO: it is utilized in converting the array of CBBUID objects for the key CBCentralManagerRestoredStateScanServicesKey in state restoration
 *  into a dicitionary where the CBUUID objects are their string equivalents and the data is converted into
 *  hex
 *  @param input Dictionary for  key  CBAdvertisementDataServiceDataKey in advertisment data
 *
 *  @return mutated Dictionary
 */
+ (NSDictionary * )collectionOfServiceAdvertismentData:(NSDictionary *)input;

/**
 *  Helper to convert the list of CBperiphreal objects into equivalent list of peipheral Dictionaries. Needed because we can
 *  seralize NSDictionary objects , the same can not be said for the CBPeripheral objcets
 *  @param input ----An array (an instance of NSArray) of CBPeripheral objects that contains all of the peripherals that were connected to the central manager (or had a connection pending) at the time the app was terminated by the system.
 *
 *  @return -- the exact replica of the input array , except the peripherals are now dictionaries and the UUID's strings and the state is also
 *  converted to a string(all for the purposes of seralization
 */

+ (NSArray *)listOfPeripherals:(NSArray *)input;


@end

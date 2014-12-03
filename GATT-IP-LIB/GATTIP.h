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

#import <Foundation/Foundation.h>

//JSON-RPC Constants
static NSString * const kJsonrpcVersion                     = @"2.0";
static NSString * const kJsonrpc                            = @"jsonrpc";
static NSString * const kMethod                             = @"method";
static NSString * const kParams                             = @"params";
static NSString * const kError                              = @"error";
static NSString * const kCode                               = @"code";
static NSString * const kMessageField                       = @"message";
static NSString * const kResult                             = @"result";
static NSString * const kIdField                            = @"id";

//-------------------------------------- Methods ----------------------------------------
//Central Methods
static NSString * const kConfigure                          = @"aa";
static NSString * const kCentralState                       = @"af";
static NSString * const kScanForPeripherals                 = @"ab";
static NSString * const kStopScanning                       = @"ac";
static NSString * const kConnect                            = @"ad";
static NSString * const kDisconnect                         = @"ae";
static NSString * const kGetConnectedPeripherals            = @"ag";
static NSString * const kGetPerhipheralsWithServices        = @"ah";
static NSString * const kGetPerhipheralsWithIdentifiers     = @"ai";

//Peripheral Methods
static NSString * const kGetServices                        = @"ak";
static NSString * const kGetIncludedServices                = @"al";
static NSString * const kGetCharacteristics                 = @"am";
static NSString * const kGetDescriptors                     = @"an";
static NSString * const kGetCharacteristicValue             = @"ao";
static NSString * const kGetDescriptorValue                 = @"ap";
static NSString * const kWriteCharacteristicValue           = @"aq";
static NSString * const kWriteDescriptorValue               = @"ar";
static NSString * const kSetValueNotification               = @"as";
static NSString * const kGetPeripheralState                 = @"at";
static NSString * const kGetRSSI                            = @"au";
static NSString * const kInvalidatedServices                = @"av";
static NSString * const kPeripheralNameUpdate               = @"aw";
static NSString * const kMessage                            = @"zz";

//-------------------------------------- Keys ----------------------------------------
static NSString * const kCentralUUID                        = @"ba";
static NSString * const kPeripheralUUID                     = @"bb";
static NSString * const kPeripheralName                     = @"bc";
static NSString * const kPeripheralUUIDs                    = @"bd";
static NSString * const kServiceUUID                        = @"be";
static NSString * const kServiceUUIDs                       = @"bf";
static NSString * const kPeripherals                        = @"bg";
static NSString * const kIncludedServiceUUIDs               = @"bh";
static NSString * const kCharacteristicUUID                 = @"bi";
static NSString * const kCharacteristicUUIDs                = @"bj";
static NSString * const kDescriptorUUID                     = @"bk";
static NSString * const kServices                           = @"bl";
static NSString * const kCharacteristics                    = @"bm";
static NSString * const kDescriptors                        = @"bn";
static NSString * const kProperties                         = @"bo";
static NSString * const kValue                              = @"bp";
static NSString * const kState                              = @"bq";
static NSString * const kStateInfo                          = @"br";
static NSString * const kStateField                         = @"bs";
static NSString * const kWriteType                          = @"bt";

static NSString * const kRSSIkey                            = @"bu";
static NSString * const kIsPrimaryKey                       = @"bv";
static NSString * const kIsBroadcasted                      = @"bw";
static NSString * const kIsNotifying                        = @"bx";

static NSString * const kShowPowerAlert                     = @"by";
static NSString * const kIdentifierKey                      = @"bz";
static NSString * const kScanOptionAllowDuplicatesKey       = @"b0";
static NSString * const kScanOptionSolicitedServiceUUIDs    = @"b1";

//Advertisment Data for Peripheral Keys
static NSString * const kAdvertisementDataKey                           = @"b2";
static NSString * const kCBAdvertisementDataManufacturerDataKey         = @"b3";
static NSString * const kCBAdvertisementDataServiceUUIDsKey             = @"b4";
static NSString * const kCBAdvertisementDataServiceDataKey              = @"b5";
static NSString * const kCBAdvertisementDataOverflowServiceUUIDsKey     = @"b6";
static NSString * const kCBAdvertisementDataSolicitedServiceUUIDsKey    = @"b7";
static NSString * const kCBAdvertisementDataIsConnectable               = @"b8";
static NSString * const kCBAdvertisementDataTxPowerLevel                = @"b9";

//Will Restore State Keys
static NSString * const kCBCentralManagerRestoredStatePeripheralsKey    = @"da";
static NSString * const kCBCentralManagerRestoredStateScanServicesKey   = @"db";

//----------------------------------------- Values ------------------------------------------------
//Characteristic Write types
static NSString * const kWriteWithResponse                = @"cc";
static NSString * const kWriteWithoutResponse             = @"cd";
static NSString * const kNotifyOnConnection               = @"ce";
static NSString * const kNotifyOnDisconnection            = @"cf";
static NSString * const kNotifyOnNotification             = @"cg";

//Peripheral States
static NSString * const kDisconnected                     = @"ch";
static NSString * const kConnecting                       = @"ci";
static NSString * const kConnected                        = @"cj";

//Centeral States
static NSString * const kUnknown                          = @"ck";
static NSString * const kResetting                        = @"cl";
static NSString * const kUnsupported                      = @"cm";
static NSString * const kUnauthorized                     = @"cn";
static NSString * const kPoweredOff                       = @"co";
static NSString * const kPoweredOn                        = @"cp";

//----------------------------------------- Error Values ------------------------------------------------
static NSString * const kError32001                     = @"-32001";//Peripheral not Found
static NSString * const kError32002                     = @"-32002";//Service not found
static NSString * const kError32003                     = @"-32003";//Characteristic Not Found
static NSString * const kError32004                     = @"-32004";//Descriptor not found
static NSString * const kError32005                     = @"-32005";//Peripheral State is Not valid(not Powered On)
static NSString * const kError32006                     = @"-32006";//No Service Specified
static NSString * const kError32007                     = @"-32007";//No Peripheral Identifer specified
static NSString * const kError32008                     = @"-32008";//@State restoration is only allowed with "bluetooth-central" background mode enabled

static NSString * const kInvalidRequest                 = @"-32600";
static NSString * const kMethodNotFound                 = @"-32601";
static NSString * const kInvalidParams                  = @"-32602";
static NSString * const kError32603                     = @"-32603";
static NSString * const kParseError                     = @"-32700";

#pragma mark- GATTIP Delegate
@protocol GATTIPDelegate <NSObject>

- (void)response:(NSData *)gattipMesg;

@end

#pragma mark- GATTIP Interface
@interface GATTIP : NSObject

@property(nonatomic, strong)id <GATTIPDelegate> delegate;

- (void)request:(NSData *)gattipMesg;

- (NSArray *)listOFResponseAndRequests;

@end
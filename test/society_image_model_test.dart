import 'package:flutter_test/flutter_test.dart';
import 'package:urban_easy_property_flutter_app/src/core/models/api_models.dart';
import 'package:urban_easy_property_flutter_app/src/core/models/app_models.dart';

void main() {
  test('resident profile image accepts profile photo containers', () {
    final ResidentRecord resident = ResidentData.fromJson(<String, dynamic>{
      'Society_ResidentID': 'resident-1',
      'Full_Name': 'Resident User',
      'Phone': '9000000000',
      'Flat_No': '101',
      'Resident_Type': 2,
      'Status': true,
      'Profile_Photo': <String, dynamic>{
        'Original_URL': 'https://example.com/resident-photo.png',
      },
    }).toResidentRecord();

    expect(resident.imageUrl, 'https://example.com/resident-photo.png');
  });

  test('resident profile image accepts nested vendor profile photo data', () {
    final ResidentRecord resident = ResidentData.fromJson(<String, dynamic>{
      'Society_ResidentID': 'resident-2',
      'Full_Name': 'Vendor Photo Resident',
      'Phone': '9000000001',
      'Flat_No': '102',
      'Resident_Type': 2,
      'Status': true,
      'Vendor_Data': <String, dynamic>{
        'Profile_Photo_Data': <String, dynamic>{
          'Image_Generation_Name': 'vendor-profile-photo',
        },
      },
    }).toResidentRecord();

    expect(
      resident.imageUrl,
      'https://urbaneasyflats.s3.ap-south-1.amazonaws.com/dev/vendor-profile-photo_Original.png',
    );
  });

  test('resident card tenant image accepts tenant vendor information container', () {
    final ResidentRecord resident = ResidentData.fromJson(<String, dynamic>{
      'Society_ResidentID': 'resident-3',
      'Full_Name': 'Tenant Resident',
      'Phone': '9000000002',
      'Flat_No': '103',
      'Resident_Type': 2,
      'Status': true,
      'Tenant_Vendor_Information': <String, dynamic>{
        'Profile_Image_Information': <String, dynamic>{
          'Image_Original_URL': 'https://example.com/tenant-resident.png',
        },
      },
    }).toResidentRecord();

    expect(resident.imageUrl, 'https://example.com/tenant-resident.png');
  });

  test('society support ticket carries resident profile photo', () {
    final TicketRecord ticket = SupportTicketData.fromJson(<String, dynamic>{
      'Support_TicketID': 'ticket-1',
      'Title': 'Society Issue',
      'Description': 'Need help',
      'Ticket_Status': 1,
      'Priority': 1,
      'Category': 1,
      'Resident_Data': <String, dynamic>{
        'Full_Name': 'Resident User',
        'Profile_Photo': <String, dynamic>{
          'Original_URL': 'https://example.com/support-resident.png',
        },
      },
    }).toTicketRecord();

    expect(ticket.residentImageUrl, 'https://example.com/support-resident.png');
  });

  test('property contract carries nested tenant profile photo', () {
    final RentalContractRecord contract = RentalContractData.fromJson(
      <String, dynamic>{
        'Rental_ContractID': 'contract-1',
        'Tenant_Name': 'Tenant User',
        'Owner_Name': 'Owner User',
        'Property_Title': 'Test Property',
        'Rent': 12000,
        'Deposit': 50000,
        'Start_Date': '2026-05-01T00:00:00.000Z',
        'End_Date': '2027-04-30T00:00:00.000Z',
        'Contract_Status': 1,
        'Status': true,
        'Tenant_Vendor_Information': <String, dynamic>{
          'Profile_Image_Information': <String, dynamic>{
            'Image_Original_URL': 'https://example.com/contract-tenant.png',
          },
        },
      },
    ).toContractRecord();

    expect(contract.tenantImageUrl, 'https://example.com/contract-tenant.png');
  });

  test('property contract can resolve tenant profile image id later', () {
    final RentalContractRecord contract = RentalContractData.fromJson(
      <String, dynamic>{
        'Rental_ContractID': 'contract-2',
        'Tenant_Name': 'Tenant User',
        'Owner_Name': 'Owner User',
        'Property_Title': 'Test Property',
        'Rent': 12000,
        'Deposit': 50000,
        'Start_Date': '2026-05-01T00:00:00.000Z',
        'End_Date': '2027-04-30T00:00:00.000Z',
        'Contract_Status': 1,
        'Status': true,
        'Tenant_Profile_Image_Information': <String, dynamic>{
          'ImageID': 'tenant-contract-image-id',
        },
      },
    ).toContractRecord();

    expect(contract.tenantImageUrl, 'imageid:tenant-contract-image-id');
  });
}

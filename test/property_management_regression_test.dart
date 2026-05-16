import 'package:flutter_test/flutter_test.dart';
import 'package:urban_easy_property_flutter_app/src/core/api/notification_service.dart';
import 'package:urban_easy_property_flutter_app/src/core/models/api_models.dart';
import 'package:urban_easy_property_flutter_app/src/core/models/app_models.dart';
import 'package:urban_easy_property_flutter_app/src/features/dashboard/dashboard_page.dart';
import 'package:urban_easy_property_flutter_app/src/features/notifications/notifications_page.dart';
import 'package:urban_easy_property_flutter_app/src/features/properties/properties_page.dart';
import 'package:urban_easy_property_flutter_app/src/features/shell/app_shell.dart';

void main() {
  group('property management regression checks', () {
    test('dashboard enquiry count accepts backend count aliases', () {
      final PropertySummaryData summary =
          PropertySummaryData.fromJson(<String, dynamic>{
            'Total_Properties_Count': 4,
            'Approved_Properties_Count': 3,
            'Rejected_Properties_Count': 0,
            'Pending_Properties_Count': 1,
            'Total_Unseen_Leads': '7',
          });

      expect(summary.newEnquiriesCount, 7);
    });

    test('subscription calculation accepts numeric strings from backend', () {
      final SubscriptionCalculationData calculation =
          SubscriptionCalculationData.fromJson(<String, dynamic>{
            'Subscription_Price': 999,
            'Active_Rental_Contracts_Count': '6',
            'Free_Contracts_Count': '5',
            'Extra_Contracts_Count': '1',
            'Total_Available_Contracts': '6',
          });

      expect(calculation.activeRentalContractsCount, 6);
      expect(calculation.freeContractsCount, 5);
      expect(calculation.extraContractsCount, 1);
      expect(calculation.totalAvailableContracts, 6);
    });

    test('renewal reduction shows required extra contract popup message', () {
      const int activeContracts = 9;
      const int freeContracts = 5;
      const int requestedExtraContracts = 2;
      const int requiredExtraContracts = activeContracts - freeContracts;
      final String? message = propertyRenewalContractReductionMessage(
        activeContracts: activeContracts,
        freeContracts: freeContracts,
        requestedExtraContracts: requestedExtraContracts,
      );

      expect(message, isNotNull);
      expect(message, contains('$activeContracts Active contracts'));
      expect(message, contains('$requiredExtraContracts purchased'));
      expect(message, contains('$freeContracts free contracts'));
      expect(message, contains('$requiredExtraContracts extra contracts'));
      expect(
        propertyRenewalContractReductionMessage(
          activeContracts: activeContracts,
          freeContracts: freeContracts,
          requestedExtraContracts: requiredExtraContracts,
        ),
        isNull,
      );
    });

    test('rental contract carries tenant profile photo to app model', () {
      final RentalContractRecord contract = RentalContractData.fromJson(
        <String, dynamic>{
          'Rental_ContractID': 'contract-1',
          'Tenant_Name': 'Tenant User',
          'Owner_Name': 'Owner',
          'Property_Title': 'Test Property',
          'Monthly_Rent': 12000,
          'Security_Deposit': 30000,
          'Contract_Start_Date': '2026-05-01',
          'Contract_End_Date': '2027-05-01',
          'Tenant_Profile_Image_Information': <String, dynamic>{
            'Image_Original_URL': 'https://example.com/tenant.png',
          },
        },
      ).toContractRecord();

      expect(contract.tenantImageUrl, 'https://example.com/tenant.png');
    });

    test(
      'bill carries tenant profile photo without using payment proof image',
      () {
        final BillRecord bill = BillData.fromJson(<String, dynamic>{
          'BillID': 'bill-1',
          'Bill_Title': 'Rent Bill',
          'Bill_Final_Amount': 12000,
          'Bill_Due_Date': '2026-05-31',
          'Bill_Status': 1,
          'Property_Rental_Contract_Information': <String, dynamic>{
            'Tenant_Name': 'Tenant User',
            'Tenant_Profile_Image_Information': <String, dynamic>{
              'Image_Original_URL': 'https://example.com/tenant.png',
            },
          },
          'Bill_Payment_Image_Information': <String, dynamic>{
            'Image_Original_URL': 'https://example.com/proof.png',
          },
        }).toBillRecord();

        expect(bill.tenantImageUrl, 'https://example.com/tenant.png');
        expect(bill.paymentImageUrl, 'https://example.com/proof.png');
      },
    );

    test(
      'property support ticket carries tenant photo and keeps attachment separate',
      () {
        final TicketRecord ticket = SupportTicketData.fromJson(
          <String, dynamic>{
            'Support_TicketID': 'ticket-1',
            'Title': 'Issue',
            'Description': 'Need help',
            'Ticket_Status': 1,
            'Priority': 1,
            'Category': 1,
            'Image_Information': <String, dynamic>{
              'Image_Original_URL': 'https://example.com/attachment.png',
            },
            'Rental_Contract_Data': <String, dynamic>{
              'Tenant_Name': 'Tenant User',
              'Tenant_Profile_Image_Information': <String, dynamic>{
                'Image_Original_URL': 'https://example.com/tenant.png',
              },
            },
          },
        ).toTicketRecord();

        expect(ticket.tenantImageUrl, 'https://example.com/tenant.png');
        expect(ticket.imageUrl, 'https://example.com/attachment.png');
      },
    );

    test(
      'announcement timestamps without timezone are displayed as backend UTC',
      () {
        final AnnouncementRecord announcement =
            AnnouncementData.fromJson(<String, dynamic>{
              'Society_AnnouncementID': 'announcement-1',
              'Title': 'check time 8.30',
              'Description': 'check time',
              'Priority': 1,
              'createdAt': '2026-05-09T15:00:00.000',
            }).toAnnouncementRecord();

        final DateTime expectedLocal = DateTime.utc(2026, 5, 9, 15).toLocal();
        expect(announcement.createdAt, expectedLocal);
        expect(formatClock(announcement.createdAt), formatClock(expectedLocal));
      },
    );

    test('resident profile image accepts uploaded image generation names', () {
      final ResidentRecord resident = ResidentData.fromJson(<String, dynamic>{
        'Society_ResidentID': 'resident-1',
        'Full_Name': 'Resident User',
        'Phone': '9000000000',
        'Flat_No': '101',
        'Resident_Type': 2,
        'Status': true,
        'Resident_Profile_Image_Information': <String, dynamic>{
          'Image_Generation_Name': 'resident-profile-image',
        },
      }).toResidentRecord();

      expect(
        resident.imageUrl,
        'https://urbaneasyflats.s3.ap-south-1.amazonaws.com/dev/resident-profile-image_Original.png',
      );
    });

    test('resident profile image accepts nested tenant vendor image data', () {
      final ResidentRecord resident = ResidentData.fromJson(<String, dynamic>{
        'Society_ResidentID': 'resident-2',
        'Full_Name': 'Nested Resident',
        'Phone': '9000000001',
        'Flat_No': '102',
        'Resident_Type': 2,
        'Status': true,
        'Tenant_Vendor_Data': <String, dynamic>{
          'Image_Information': <String, dynamic>{
            'Image_Generation_Name': 'nested-resident-profile',
          },
        },
      }).toResidentRecord();

      expect(
        resident.imageUrl,
        'https://urbaneasyflats.s3.ap-south-1.amazonaws.com/dev/nested-resident-profile_Original.png',
      );
    });

    test('resident profile image accepts profile photo containers', () {
      final ResidentRecord resident = ResidentData.fromJson(<String, dynamic>{
        'Society_ResidentID': 'resident-2b',
        'Full_Name': 'Photo Resident',
        'Phone': '9000000003',
        'Flat_No': '104',
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
        'Society_ResidentID': 'resident-2c',
        'Full_Name': 'Vendor Photo Resident',
        'Phone': '9000000004',
        'Flat_No': '105',
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

    test('resident profile image falls back to image id reference', () {
      final ResidentRecord resident = ResidentData.fromJson(<String, dynamic>{
        'Society_ResidentID': 'resident-3',
        'Full_Name': 'Image Id Resident',
        'Phone': '9000000002',
        'Flat_No': '103',
        'Resident_Type': 2,
        'Status': true,
        'Resident_Profile_Image_Information': <String, dynamic>{
          'ImageID': 'image-id-123',
        },
      }).toResidentRecord();

      expect(resident.imageUrl, 'imageid:image-id-123');
    });

    test('society support ticket carries resident profile photo', () {
      final TicketRecord ticket = SupportTicketData.fromJson(
        <String, dynamic>{
          'Support_TicketID': 'ticket-2',
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
        },
      ).toTicketRecord();

      expect(
        ticket.residentImageUrl,
        'https://example.com/support-resident.png',
      );
    });

    test('property support ticket tenant photo falls back to image id reference', () {
      final TicketRecord ticket = SupportTicketData.fromJson(
        <String, dynamic>{
          'Support_TicketID': 'ticket-3',
          'Title': 'Property Issue',
          'Description': 'Need help',
          'Ticket_Status': 1,
          'Priority': 1,
          'Category': 1,
          'Rental_Contract_Data': <String, dynamic>{
            'Tenant_Name': 'Tenant User',
            'Tenant_Profile_Photo': <String, dynamic>{
              'Profile_PhotoID': 'tenant-image-id',
            },
          },
        },
      ).toTicketRecord();

      expect(ticket.tenantImageUrl, 'imageid:tenant-image-id');
    });

    test('open property enquiry can be shown as notification dynamically', () {
      final DateTime createdAt = DateTime.utc(2026, 5, 10, 8, 1);
      final NotificationData notification =
          NotificationData.fromPropertyEnquiry(
            PropertyEnquiryData(
              enquiryId: 'enquiry-1',
              name: 'Testing Tenant',
              phone: '9000000000',
              status: 1,
              email: 'tenant@example.com',
              propertyId: 'property-1',
              propertyTitle: 'Sai PG',
              ownerName: 'Owner User',
              createdAt: createdAt,
            ),
          );

      expect(notification.type, 'enquiry');
      expect(notification.isLocalPropertyEnquiry, isTrue);
      expect(notification.referenceId, 'enquiry-1');
      expect(notification.message, contains('Mobile: 9000000000'));
      expect(notification.message, contains('Property: Sai PG'));
      expect(notification.createdAt, createdAt);
    });

    test('backend enquiry notifications are not duplicated by local merge', () {
      final NotificationData backend =
          NotificationData.fromJson(<String, dynamic>{
            'Vendor_NotificationID': 'notification-1',
            'Title': 'New Property Enquiry',
            'Message': 'Backend enquiry',
            'Reference_Type': 'property_enquiry',
            'Reference_ID': 'enquiry-1',
            'createdAt': '2026-05-10T08:01:00.000Z',
          });
      final NotificationData local = NotificationData.fromPropertyEnquiry(
        const PropertyEnquiryData(
          enquiryId: 'enquiry-1',
          name: 'Testing Tenant',
          phone: '9000000000',
          status: 1,
        ),
      );

      final List<NotificationData> merged =
          NotificationService.mergePropertyEnquiryNotifications(
            <NotificationData>[backend],
            <NotificationData>[local],
          );

      expect(merged, hasLength(1));
      expect(merged.single.notificationId, 'notification-1');
    });

    test('touched property UI widgets remain constructible', () {
      final DashboardPage dashboard = DashboardPage(
        role: AppRole.propertyManager,
        metrics: const <DashboardMetric>[],
        shortcuts: const <AppShortcut>[],
        announcements: const <AnnouncementRecord>[],
        tickets: const <TicketRecord>[],
        onShortcutSelected: (_) {},
        propertyEnquiryCountOverride: 3,
      );
      final AppShell shell = AppShell(
        role: AppRole.propertyManager,
        onLogout: () {},
      );

      expect(dashboard.propertyEnquiryCountOverride, 3);
      expect(const NotificationsPage(), isA<NotificationsPage>());
      expect(shell.role, AppRole.propertyManager);
    });
  });
}

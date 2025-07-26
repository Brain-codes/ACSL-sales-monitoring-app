import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:stove_transaction/core/model/supabase_api_response.dart';
import 'package:stove_transaction/core/model/profile_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService extends GetxService {
  final Logger _logger = Logger();
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch user profile with populated organization data
  Future<SupabaseApiResponse<ProfileModel>> fetchUserProfileWithOrganization(
      String userId) async {
    try {
      _logger.d('Fetching profile for user: $userId');

      // Query profiles table with organization join using Supabase client directly
      final response = await _supabase.from('profiles').select('''
            id,
            email,
            full_name,
            phone,
            role,
            has_changed_password,
            created_at,
            organization_id,
            organizations(
              id,
              name,
              created_at,
              partner_email
            )
          ''').eq('id', userId).maybeSingle();

      if (response != null) {
        // If the join didn't work but we have an organization_id, fetch it separately
        if (response['organizations'] == null &&
            response['organization_id'] != null) {
          final orgResponse = await _supabase
              .from('organizations')
              .select('id, name, created_at, partner_email')
              .eq('id', response['organization_id'])
              .maybeSingle();

          if (orgResponse != null) {
            response['organization'] = orgResponse;
          }
        }

        final profileModel = ProfileModel.fromJson(response);
        return SupabaseApiResponse.success(profileModel);
      } else {
        _logger.w('No profile found for user: $userId');
        return SupabaseApiResponse.error('Profile not found', code: 404);
      }
    } catch (e) {
      _logger.e('Error fetching profile: $e');
      return SupabaseApiResponse.error('Failed to fetch profile: $e',
          code: 500);
    }
  }

  /// Update user profile
  Future<SupabaseApiResponse<ProfileModel>> updateUserProfile({
    required String userId,
    String? fullName,
    String? phone,
    bool? hasChangedPassword,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (fullName != null) updateData['full_name'] = fullName;
      if (phone != null) updateData['phone'] = phone;
      if (hasChangedPassword != null)
        updateData['has_changed_password'] = hasChangedPassword;

      if (updateData.isEmpty) {
        return SupabaseApiResponse.error('No data to update', code: 400);
      }

      final response = await _supabase
          .from('profiles')
          .update(updateData)
          .eq('id', userId)
          .select('''
            id,
            email,
            full_name,
            phone,
            role,
            has_changed_password,
            created_at,
            organization_id,
            organizations(
              id,
              name,
              created_at,
              partner_email
            )
          ''').maybeSingle();

      if (response != null) {
        final profileModel = ProfileModel.fromJson(response);
        _logger.d('Profile updated successfully for user: $userId');
        return SupabaseApiResponse.success(profileModel);
      } else {
        _logger.e('Failed to update profile: No response received');
        return SupabaseApiResponse.error('Failed to update profile', code: 500);
      }
    } catch (e) {
      _logger.e('Error updating profile: $e');
      return SupabaseApiResponse.error('Failed to update profile: $e',
          code: 500);
    }
  }
}

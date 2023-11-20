import 'dart:convert';
import 'dart:io';

import 'package:appflowy/env/backend_env.dart';
import 'package:appflowy/env/env.dart';
import 'package:appflowy/user/application/auth/device_id.dart';
import 'package:appflowy_backend/appflowy_backend.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../startup.dart';

class InitRustSDKTask extends LaunchTask {
  const InitRustSDKTask({
    this.customApplicationPath,
  });

  // Customize the RustSDK initialization path
  final Directory? customApplicationPath;

  @override
  LaunchTaskType get type => LaunchTaskType.dataProcessing;

  @override
  Future<void> initialize(LaunchContext context) async {
    final applicationPath = await appFlowyApplicationDataDirectory();
    final dir = customApplicationPath ?? applicationPath;
    final deviceId = await getDeviceId();

    // Pass the environment variables to the Rust SDK
    final env = _getAppFlowyConfiguration(
      dir.path,
      applicationPath.path,
      deviceId,
    );
    await context.getIt<FlowySDK>().init(jsonEncode(env.toJson()));
  }

  @override
  Future<void> dispose() async {}
}

AppFlowyConfiguration _getAppFlowyConfiguration(
  String customAppPath,
  String originAppPath,
  String deviceId,
) {
  if (isCloudEnabled) {
    final supabaseConfig = SupabaseConfiguration(
      url: Env.supabaseUrl,
      anon_key: Env.supabaseAnonKey,
    );

    final appflowyCloudConfig = AppFlowyCloudConfiguration(
      base_url: Env.afCloudBaseUrl,
      ws_base_url: Env.afCloudWSBaseUrl,
      gotrue_url: Env.afCloudGoTrueUrl,
    );

    return AppFlowyConfiguration(
      custom_app_path: customAppPath,
      origin_app_path: originAppPath,
      device_id: deviceId,
      cloud_type: Env.cloudType,
      supabase_config: supabaseConfig,
      appflowy_cloud_config: appflowyCloudConfig,
    );
  } else {
    // Use the default configuration if the cloud feature is disabled
    final supabaseConfig = SupabaseConfiguration.defaultConfig();
    final appflowyCloudConfig = AppFlowyCloudConfiguration.defaultConfig();

    return AppFlowyConfiguration(
      custom_app_path: customAppPath,
      origin_app_path: originAppPath,
      device_id: deviceId,
      // 0 means the cloud type is local
      cloud_type: 0,
      supabase_config: supabaseConfig,
      appflowy_cloud_config: appflowyCloudConfig,
    );
  }
}

/// The default directory to store the user data. The directory can be
/// customized by the user via the [ApplicationDataStorage]
Future<Directory> appFlowyApplicationDataDirectory() async {
  switch (integrationMode()) {
    case IntegrationMode.develop:
      final Directory documentsDir = await getApplicationSupportDirectory()
        ..create();
      return Directory(path.join(documentsDir.path, 'data_dev')).create();
    case IntegrationMode.release:
      final Directory documentsDir = await getApplicationSupportDirectory();
      return Directory(path.join(documentsDir.path, 'data')).create();
    case IntegrationMode.unitTest:
    case IntegrationMode.integrationTest:
      return Directory(path.join(Directory.current.path, '.sandbox'));
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unifiedpush_platform_interface/unifiedpush_platform_interface.dart';

import 'constants.dart';
import 'dialogs.dart';

class UnifiedPush {
  static SharedPreferences? _prefs;

  static Future<SharedPreferences?> getSharedPreferences() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
      var migrated = _prefs?.getBool("unifiedpush/migrated");
      if (migrated == null || !migrated) {
        final nativePrefs = await UnifiedPushPlatform.instance.getAllNativeSharedPrefs();
        if (nativePrefs != null) {
          nativePrefs.forEach((key, value) {
            if (value is String) {
              _prefs?.setString(key, value);
            } else if (value is Iterable) {
              _prefs?.setStringList(key, List.from(value));
            }
          });
        }
        _prefs?.setBool("unifiedpush/migrated", true);
      }
    }
    return _prefs;
  }

  static String _preferredDistributor = "";
  static List<String> _availDistributors = [];

  /// INIT: 1.A With Callback, Default Instance
  static Future<void> initializeWithCallback(
      void Function(String endpoint, String instance) onNewEndpoint,
      void Function(String instance) onRegistrationFailed,
      void Function(String instance) onUnregistered,
      void Function(String message, String instance) onMessage,
      void Function(dynamic args) callbackOnNewEndpoint, //need to be static
      void Function(dynamic args) callbackOnUnregistered, //need to be static
      void Function(dynamic args) callbackOnMessage //need to be static
      ) async {
    await initializeWithReceiver(
      onNewEndpoint: onNewEndpoint,
      onRegistrationFailed: onRegistrationFailed,
      onUnregistered: onUnregistered,
      onMessage: onMessage,
    );
    final prefs = await getSharedPreferences();
    prefs?.setInt(
        PREF_ON_NEW_ENDPOINT_ADAPTER,
        PluginUtilities.getCallbackHandle(callbackOnNewEndpoint)?.toRawHandle() ??
            0);
    prefs?.setInt(
        PREF_ON_UNREGISTERED_ADAPTER,
        PluginUtilities.getCallbackHandle(callbackOnUnregistered)?.toRawHandle() ??
            0);
    prefs?.setInt(
        PREF_ON_MESSAGE_ADAPTER,
        PluginUtilities.getCallbackHandle(callbackOnMessage)?.toRawHandle() ??
            0);
    await UnifiedPushPlatform.instance.initializeBackgroundCallback(
      staticOnNewEndpoint: onNewEndpointAdapter,
      staticOnUnregistered: onUnregisteredAdapter,
      staticOnMessage: onMessageAdapter
    );
  }

  static onNewEndpointAdapter(dynamic args) async {
    final callback = await getCallbackFromPrefHandle(PREF_ON_NEW_ENDPOINT_ADAPTER);
    final instance = args["instance"];
    callback?.call({
      "instance" : instance,
      "endpoint" : args["endpoint"],
    });
  }

    static onUnregisteredAdapter(dynamic args) async {
    final callback = await getCallbackFromPrefHandle(PREF_ON_UNREGISTERED_ADAPTER);
    final instance = args["instance"];
    callback?.call({"instance" : instance});
  }

  static onMessageAdapter(dynamic args) async {
    final callback = await getCallbackFromPrefHandle(PREF_ON_MESSAGE_ADAPTER);
    final instance = args["instance"];
    callback?.call({
      "instance" : instance,
      "message" : args["message"],
    });
  }

  static Future<Function?> getCallbackFromPrefHandle(String prefKey) async {
    final prefs = await getSharedPreferences();
    final rawHandle = prefs?.getInt(prefKey);
    if (rawHandle != null && rawHandle != 0) {
      return PluginUtilities.getCallbackFromHandle(CallbackHandle.fromRawHandle(rawHandle));
    }
  }

  /// INIT: 2.A With Receiver, Default Instance
  static Future<void> initializeWithReceiver({
    void Function(String endpoint, String instance)? onNewEndpoint,
    void Function(String instance)? onRegistrationFailed,
    void Function(String instance)? onUnregistered,
    void Function(String message, String instance)? onMessage,
  }) async {
    await UnifiedPushPlatform.instance.initializeCallback(
      onNewEndpoint: (String e, String i) async => onNewEndpoint?.call(e, i),
      onRegistrationFailed: (String i) async => onRegistrationFailed?.call(i),
      onUnregistered: (String i) async => onUnregistered?.call(i),
      onMessage: (String m, String i) async => onMessage?.call(m, i)
    );
  }

  static Future<void> registerAppWithDialog(BuildContext context, [String instance = DEFAULT_INSTANCE]) async {
    var distributor = await getDistributor();
    if (distributor == "") {
      final distributors = await getDistributors();
      if (distributors.isEmpty) {
        await showDialog(context: context, builder: noDistributorDialog());
      } else {
        final picked = await showDialog<String>(
          context: context,
          builder: pickDistributorDialog(distributors),
        );
        if (picked != null) {
          await saveDistributor(picked);
        }
      }
    }

    await registerApp(instance = instance);
  }

  static Future<void> registerApp([String instance = DEFAULT_INSTANCE]) async {
    UnifiedPushPlatform.instance.registerApp(instance);
  }

  static Future<void> unregister([String instance = DEFAULT_INSTANCE]) async {
    UnifiedPushPlatform.instance.unregister(instance);
  }

  static Future<List<String>> getDistributors() async {
    if (_availDistributors.isEmpty) {
      _availDistributors = await UnifiedPushPlatform.instance.getDistributors();
    }
    return _availDistributors;
  }

  static Future<String> getDistributor() async {
    if (_preferredDistributor.isEmpty) {
      _preferredDistributor = await UnifiedPushPlatform.instance.getDistributor();
    }
    return _preferredDistributor;
  }

  static Future<void> saveDistributor(String distributor) async {
    _preferredDistributor = distributor;
    UnifiedPushPlatform.instance.saveDistributor(distributor);
  }
}

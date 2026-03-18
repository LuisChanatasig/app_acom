//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import audio_session
import flutter_local_notifications
import just_audio
import local_auth_darwin
import shared_preferences_foundation

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  AudioSessionPlugin.register(with: registry.registrar(forPlugin: "AudioSessionPlugin"))
  FlutterLocalNotificationsPlugin.register(with: registry.registrar(forPlugin: "FlutterLocalNotificationsPlugin"))
  JustAudioPlugin.register(with: registry.registrar(forPlugin: "JustAudioPlugin"))
  LocalAuthPlugin.register(with: registry.registrar(forPlugin: "LocalAuthPlugin"))
  SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
}

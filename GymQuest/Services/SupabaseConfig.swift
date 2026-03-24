//
//  SupabaseConfig.swift
//  GymQuest
//
//  Supabase client configuration for backend integration.
//

import Foundation
import Supabase

enum SupabaseConfig {
    static let projectURL = URL(string: "https://sdcvbubthjavmmicoigu.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNkY3ZidWJ0aGphdm1taWNvaWd1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQwNjQ3NjEsImV4cCI6MjA4OTY0MDc2MX0.S2dKrYDwPVAldGRS4CJbtO5wEafsZc6MEuFbXrH170w"

    static let client = SupabaseClient(
        supabaseURL: projectURL,
        supabaseKey: anonKey
    )
}

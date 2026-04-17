import Foundation
import Supabase

enum SupabaseManager {
    static let shared: SupabaseClient = SupabaseClient(
        supabaseURL: Secrets.supabaseURL,
        supabaseKey: Secrets.supabaseAnonKey
    )
}

//
//  SupabaseManger.swift
//  Max
//
//  Created by Santiago Jojoa on 29/08/26.
//

import Foundation
import Supabase

let supabaseURL = URL(string: "https://xdrzpomkcjgcggafzlfe.supabase.co")!
let supabaseKey = "sb_publishable_L0jlD3n-XnhD1OaL721dFQ_wIB3Ga_s"

let supabase = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)

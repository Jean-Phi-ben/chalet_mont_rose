# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_04_110000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "booking_settings", force: :cascade do |t|
    t.integer "cleaning_fee_cents", default: 40000, null: false
    t.datetime "created_at", null: false
    t.integer "tourist_tax_per_person_per_night_cents", default: 260, null: false
    t.datetime "updated_at", null: false
    t.decimal "vat_rate_percent", precision: 5, scale: 2, default: "10.0", null: false
  end

  create_table "bookings", force: :cascade do |t|
    t.integer "accommodation_cents", default: 0, null: false
    t.date "check_in", null: false
    t.date "check_out", null: false
    t.integer "cleaning_fee_cents", default: 0, null: false
    t.bigint "client_id"
    t.datetime "created_at", null: false
    t.integer "deposit_cents"
    t.string "email", null: false
    t.string "first_name", null: false
    t.integer "guests_count"
    t.datetime "invoicing_archived_at"
    t.string "last_name", null: false
    t.text "message"
    t.string "phone"
    t.integer "status", default: 0, null: false
    t.string "token", null: false
    t.integer "total_price_cents"
    t.integer "tourist_tax_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.decimal "vat_rate_percent", precision: 5, scale: 2, default: "10.0", null: false
    t.index ["check_in"], name: "index_bookings_on_check_in"
    t.index ["client_id"], name: "index_bookings_on_client_id"
    t.index ["status"], name: "index_bookings_on_status"
    t.index ["token"], name: "index_bookings_on_token", unique: true
    t.index ["user_id"], name: "index_bookings_on_user_id"
  end

  create_table "clients", force: :cascade do |t|
    t.text "address"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_clients_on_email", unique: true
  end

  create_table "invoices", force: :cascade do |t|
    t.integer "amount_cents", default: 0, null: false
    t.datetime "balance_reminder_sent_at"
    t.bigint "booking_id", null: false
    t.datetime "created_at", null: false
    t.datetime "forwarded_to_dext_at"
    t.date "issued_on", null: false
    t.integer "kind", default: 0, null: false
    t.string "number", null: false
    t.date "received_on"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["booking_id", "kind"], name: "index_invoices_on_booking_id_and_kind", unique: true
    t.index ["booking_id"], name: "index_invoices_on_booking_id"
    t.index ["number"], name: "index_invoices_on_number", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "tourist_tax_periods", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "paid", default: false, null: false
    t.date "paid_on"
    t.string "season", null: false
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index ["season", "year"], name: "index_tourist_tax_periods_on_season_and_year", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin"
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "weekly_rates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "min_weeks", default: 1, null: false
    t.string "note"
    t.integer "price_cents", null: false
    t.datetime "updated_at", null: false
    t.date "week_start", null: false
    t.index ["week_start"], name: "index_weekly_rates_on_week_start", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "bookings", "clients"
  add_foreign_key "bookings", "users"
  add_foreign_key "invoices", "bookings"
  add_foreign_key "sessions", "users"
end

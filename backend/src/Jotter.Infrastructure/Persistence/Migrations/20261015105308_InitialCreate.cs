using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace Jotter.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateSequence(
                name: "change_seq");

            migrationBuilder.CreateTable(
                name: "processed_operations",
                columns: table => new
                {
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    operation_id = table.Column<Guid>(type: "uuid", nullable: false),
                    status_code = table.Column<int>(type: "integer", nullable: false),
                    content_type = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    response_body = table.Column<byte[]>(type: "bytea", nullable: false),
                    processed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_processed_operations", x => new { x.user_id, x.operation_id });
                });

            migrationBuilder.CreateTable(
                name: "purge_checkpoints",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false),
                    purged_change_seq = table.Column<long>(type: "bigint", nullable: false),
                    purged_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_purge_checkpoints", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "users",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    display_name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    avatar_storage_key = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    user_name = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: true),
                    normalized_user_name = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: true),
                    email = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: true),
                    normalized_email = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: true),
                    email_confirmed = table.Column<bool>(type: "boolean", nullable: false),
                    password_hash = table.Column<string>(type: "text", nullable: true),
                    security_stamp = table.Column<string>(type: "text", nullable: true),
                    concurrency_stamp = table.Column<string>(type: "text", nullable: true),
                    phone_number = table.Column<string>(type: "text", nullable: true),
                    phone_number_confirmed = table.Column<bool>(type: "boolean", nullable: false),
                    two_factor_enabled = table.Column<bool>(type: "boolean", nullable: false),
                    lockout_end = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    lockout_enabled = table.Column<bool>(type: "boolean", nullable: false),
                    access_failed_count = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_users", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "labels",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    owner_id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    change_seq = table.Column<long>(type: "bigint", nullable: false),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_labels", x => x.id);
                    table.ForeignKey(
                        name: "fk_labels_asp_net_users_owner_id",
                        column: x => x.owner_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "notes",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    owner_id = table.Column<Guid>(type: "uuid", nullable: false),
                    conflict_of_note_id = table.Column<Guid>(type: "uuid", nullable: true),
                    title = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    content = table.Column<string>(type: "text", nullable: false),
                    search_title = table.Column<string>(type: "text", nullable: false),
                    search_content = table.Column<string>(type: "text", nullable: false),
                    is_pinned = table.Column<bool>(type: "boolean", nullable: false),
                    pinned_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    is_protected = table.Column<bool>(type: "boolean", nullable: false),
                    password_hash = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: true),
                    version = table.Column<long>(type: "bigint", nullable: false),
                    change_seq = table.Column<long>(type: "bigint", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_notes", x => x.id);
                    table.ForeignKey(
                        name: "fk_notes_asp_net_users_owner_id",
                        column: x => x.owner_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_notes_notes_conflict_of_note_id",
                        column: x => x.conflict_of_note_id,
                        principalTable: "notes",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "password_reset_tickets",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    ticket_hash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    expires_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    consumed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_password_reset_tickets", x => x.id);
                    table.ForeignKey(
                        name: "fk_password_reset_tickets_asp_net_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "user_claims",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    claim_type = table.Column<string>(type: "text", nullable: true),
                    claim_value = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_user_claims", x => x.id);
                    table.ForeignKey(
                        name: "fk_user_claims_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "user_logins",
                columns: table => new
                {
                    login_provider = table.Column<string>(type: "text", nullable: false),
                    provider_key = table.Column<string>(type: "text", nullable: false),
                    provider_display_name = table.Column<string>(type: "text", nullable: true),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_user_logins", x => new { x.login_provider, x.provider_key });
                    table.ForeignKey(
                        name: "fk_user_logins_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "user_preferences",
                columns: table => new
                {
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    note_font_size = table.Column<int>(type: "integer", nullable: false),
                    default_note_color = table.Column<string>(type: "character varying(7)", maxLength: 7, nullable: false),
                    theme_mode = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    list_view_mode = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_user_preferences", x => x.user_id);
                    table.ForeignKey(
                        name: "fk_user_preferences_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "user_sessions",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    issued_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    expires_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    revoked_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_user_sessions", x => x.id);
                    table.ForeignKey(
                        name: "fk_user_sessions_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "user_tokens",
                columns: table => new
                {
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    login_provider = table.Column<string>(type: "text", nullable: false),
                    name = table.Column<string>(type: "text", nullable: false),
                    value = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_user_tokens", x => new { x.user_id, x.login_provider, x.name });
                    table.ForeignKey(
                        name: "fk_user_tokens_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "verification_codes",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    purpose = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    code_hash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    expires_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    attempt_count = table.Column<int>(type: "integer", nullable: false),
                    consumed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    invalidated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_verification_codes", x => x.id);
                    table.ForeignKey(
                        name: "fk_verification_codes_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "attachments",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    note_id = table.Column<Guid>(type: "uuid", nullable: false),
                    file_name = table.Column<string>(type: "character varying(255)", maxLength: 255, nullable: false),
                    mime_type = table.Column<string>(type: "character varying(127)", maxLength: 127, nullable: false),
                    size_bytes = table.Column<long>(type: "bigint", nullable: false),
                    storage_key = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    uploaded_by = table.Column<Guid>(type: "uuid", nullable: false),
                    uploaded_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    deleted_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    change_seq = table.Column<long>(type: "bigint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_attachments", x => x.id);
                    table.ForeignKey(
                        name: "fk_attachments_asp_net_users_uploaded_by",
                        column: x => x.uploaded_by,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "fk_attachments_notes_note_id",
                        column: x => x.note_id,
                        principalTable: "notes",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "note_embeddings",
                columns: table => new
                {
                    note_id = table.Column<Guid>(type: "uuid", nullable: false),
                    chunk_index = table.Column<int>(type: "integer", nullable: false),
                    chunk_text = table.Column<string>(type: "text", nullable: false),
                    vector = table.Column<float[]>(type: "real[]", nullable: false),
                    indexed_version = table.Column<long>(type: "bigint", nullable: false),
                    indexed_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_note_embeddings", x => new { x.note_id, x.chunk_index });
                    table.ForeignKey(
                        name: "fk_note_embeddings_notes_note_id",
                        column: x => x.note_id,
                        principalTable: "notes",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "note_labels",
                columns: table => new
                {
                    note_id = table.Column<Guid>(type: "uuid", nullable: false),
                    label_id = table.Column<Guid>(type: "uuid", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_note_labels", x => new { x.note_id, x.label_id });
                    table.ForeignKey(
                        name: "fk_note_labels_labels_label_id",
                        column: x => x.label_id,
                        principalTable: "labels",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_note_labels_notes_note_id",
                        column: x => x.note_id,
                        principalTable: "notes",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "note_summaries",
                columns: table => new
                {
                    note_id = table.Column<Guid>(type: "uuid", nullable: false),
                    summary_text = table.Column<string>(type: "text", nullable: false),
                    generated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_note_summaries", x => x.note_id);
                    table.ForeignKey(
                        name: "fk_note_summaries_notes_note_id",
                        column: x => x.note_id,
                        principalTable: "notes",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "note_unlock_sessions",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    note_id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    issued_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    expires_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_note_unlock_sessions", x => x.id);
                    table.ForeignKey(
                        name: "fk_note_unlock_sessions_asp_net_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_note_unlock_sessions_notes_note_id",
                        column: x => x.note_id,
                        principalTable: "notes",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "share_grants",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    note_id = table.Column<Guid>(type: "uuid", nullable: false),
                    recipient_user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    permission = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    shared_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    revoked_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    change_seq = table.Column<long>(type: "bigint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_share_grants", x => x.id);
                    table.ForeignKey(
                        name: "fk_share_grants_asp_net_users_recipient_user_id",
                        column: x => x.recipient_user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "fk_share_grants_notes_note_id",
                        column: x => x.note_id,
                        principalTable: "notes",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_attachments_change_seq",
                table: "attachments",
                column: "change_seq");

            migrationBuilder.CreateIndex(
                name: "ix_attachments_note_id",
                table: "attachments",
                column: "note_id");

            migrationBuilder.CreateIndex(
                name: "ix_attachments_storage_key",
                table: "attachments",
                column: "storage_key",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_attachments_uploaded_by",
                table: "attachments",
                column: "uploaded_by");

            migrationBuilder.CreateIndex(
                name: "ix_labels_owner_id_change_seq",
                table: "labels",
                columns: new[] { "owner_id", "change_seq" });

            migrationBuilder.CreateIndex(
                name: "ix_labels_owner_id_name",
                table: "labels",
                columns: new[] { "owner_id", "name" },
                unique: true,
                filter: "deleted_at IS NULL");

            migrationBuilder.CreateIndex(
                name: "ix_note_labels_label_id",
                table: "note_labels",
                column: "label_id");

            migrationBuilder.CreateIndex(
                name: "ix_note_unlock_sessions_note_id_expires_at",
                table: "note_unlock_sessions",
                columns: new[] { "note_id", "expires_at" });

            migrationBuilder.CreateIndex(
                name: "ix_note_unlock_sessions_user_id_note_id_expires_at",
                table: "note_unlock_sessions",
                columns: new[] { "user_id", "note_id", "expires_at" });

            migrationBuilder.CreateIndex(
                name: "ix_notes_change_seq",
                table: "notes",
                column: "change_seq");

            migrationBuilder.CreateIndex(
                name: "ix_notes_conflict_of_note_id",
                table: "notes",
                column: "conflict_of_note_id");

            migrationBuilder.CreateIndex(
                name: "ix_notes_owner_id_change_seq",
                table: "notes",
                columns: new[] { "owner_id", "change_seq" });

            migrationBuilder.CreateIndex(
                name: "ix_password_reset_tickets_ticket_hash",
                table: "password_reset_tickets",
                column: "ticket_hash",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_password_reset_tickets_user_id",
                table: "password_reset_tickets",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "ix_processed_operations_processed_at",
                table: "processed_operations",
                column: "processed_at");

            migrationBuilder.CreateIndex(
                name: "ix_share_grants_change_seq",
                table: "share_grants",
                column: "change_seq");

            migrationBuilder.CreateIndex(
                name: "ix_share_grants_note_id_recipient_user_id",
                table: "share_grants",
                columns: new[] { "note_id", "recipient_user_id" },
                unique: true,
                filter: "revoked_at IS NULL");

            migrationBuilder.CreateIndex(
                name: "ix_share_grants_recipient_user_id_change_seq",
                table: "share_grants",
                columns: new[] { "recipient_user_id", "change_seq" });

            migrationBuilder.CreateIndex(
                name: "ix_user_claims_user_id",
                table: "user_claims",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "ix_user_logins_user_id",
                table: "user_logins",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "ix_user_sessions_user_id",
                table: "user_sessions",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "EmailIndex",
                table: "users",
                column: "normalized_email",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "UserNameIndex",
                table: "users",
                column: "normalized_user_name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ix_verification_codes_user_id_purpose_created_at",
                table: "verification_codes",
                columns: new[] { "user_id", "purpose", "created_at" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "attachments");

            migrationBuilder.DropTable(
                name: "note_embeddings");

            migrationBuilder.DropTable(
                name: "note_labels");

            migrationBuilder.DropTable(
                name: "note_summaries");

            migrationBuilder.DropTable(
                name: "note_unlock_sessions");

            migrationBuilder.DropTable(
                name: "password_reset_tickets");

            migrationBuilder.DropTable(
                name: "processed_operations");

            migrationBuilder.DropTable(
                name: "purge_checkpoints");

            migrationBuilder.DropTable(
                name: "share_grants");

            migrationBuilder.DropTable(
                name: "user_claims");

            migrationBuilder.DropTable(
                name: "user_logins");

            migrationBuilder.DropTable(
                name: "user_preferences");

            migrationBuilder.DropTable(
                name: "user_sessions");

            migrationBuilder.DropTable(
                name: "user_tokens");

            migrationBuilder.DropTable(
                name: "verification_codes");

            migrationBuilder.DropTable(
                name: "labels");

            migrationBuilder.DropTable(
                name: "notes");

            migrationBuilder.DropTable(
                name: "users");

            migrationBuilder.DropSequence(
                name: "change_seq");
        }
    }
}

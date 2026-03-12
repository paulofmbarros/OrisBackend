using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Oris.Infrastructure.Migrations;

/// <inheritdoc />
public partial class AddTrainingSessionPersistenceDetails : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<DateTime>(
            name: "LockedAt",
            table: "TrainingSessions",
            type: "timestamp with time zone",
            nullable: true);

        migrationBuilder.AddColumn<DateTime>(
            name: "CompletedAt",
            table: "TrainingSessions",
            type: "timestamp with time zone",
            nullable: true);

        // Migrate existing IsCompleted data to CompletedAt
        migrationBuilder.Sql("UPDATE \"TrainingSessions\" SET \"CompletedAt\" = \"UpdatedAt\" WHERE \"IsCompleted\" = true");

        migrationBuilder.DropColumn(
            name: "IsCompleted",
            table: "TrainingSessions");

        migrationBuilder.AddColumn<int>(
            name: "Order",
            table: "PlannedExercises",
            type: "integer",
            nullable: false,
            defaultValue: 0);

        migrationBuilder.AddColumn<double>(
            name: "SuggestedLoad",
            table: "PlannedExercises",
            type: "double precision",
            nullable: true);

        migrationBuilder.AddColumn<int>(
            name: "RestTimeSeconds",
            table: "PlannedExercises",
            type: "integer",
            nullable: true);
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<bool>(
            name: "IsCompleted",
            table: "TrainingSessions",
            type: "boolean",
            nullable: false,
            defaultValue: false);

        migrationBuilder.Sql("UPDATE \"TrainingSessions\" SET \"IsCompleted\" = true WHERE \"CompletedAt\" IS NOT NULL");

        migrationBuilder.DropColumn(
            name: "LockedAt",
            table: "TrainingSessions");

        migrationBuilder.DropColumn(
            name: "CompletedAt",
            table: "TrainingSessions");

        migrationBuilder.DropColumn(
            name: "Order",
            table: "PlannedExercises");

        migrationBuilder.DropColumn(
            name: "SuggestedLoad",
            table: "PlannedExercises");

        migrationBuilder.DropColumn(
            name: "RestTimeSeconds",
            table: "PlannedExercises");
    }
}

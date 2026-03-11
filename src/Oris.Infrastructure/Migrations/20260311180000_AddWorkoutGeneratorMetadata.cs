using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Oris.Infrastructure.Migrations;

/// <inheritdoc />
public partial class AddWorkoutGeneratorMetadata : Migration
{
    /// <inheritdoc />
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<string>(
            name: "AvailableEquipment",
            table: "Users",
            type: "text",
            nullable: false,
            defaultValue: "[]");

        migrationBuilder.AddColumn<string>(
            name: "FavoriteExerciseIds",
            table: "Users",
            type: "text",
            nullable: false,
            defaultValue: "[]");

        migrationBuilder.AddColumn<int>(
            name: "WorkoutDurationCapMinutes",
            table: "Users",
            type: "integer",
            nullable: false,
            defaultValue: 60);

        migrationBuilder.AddColumn<int>(
            name: "MovementPattern",
            table: "Exercises",
            type: "integer",
            nullable: false,
            defaultValue: 0);

        migrationBuilder.AddColumn<string>(
            name: "RequiredEquipment",
            table: "Exercises",
            type: "text",
            nullable: false,
            defaultValue: "[]");
    }

    /// <inheritdoc />
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropColumn(
            name: "AvailableEquipment",
            table: "Users");

        migrationBuilder.DropColumn(
            name: "FavoriteExerciseIds",
            table: "Users");

        migrationBuilder.DropColumn(
            name: "WorkoutDurationCapMinutes",
            table: "Users");

        migrationBuilder.DropColumn(
            name: "MovementPattern",
            table: "Exercises");

        migrationBuilder.DropColumn(
            name: "RequiredEquipment",
            table: "Exercises");
    }
}

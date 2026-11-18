<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('users', function (Blueprint $t) {
            $t->string('photo_path')->nullable();
            $t->string('gender', 1)->nullable();
            $t->string('hometown', 80)->nullable();
            $t->string('emergency_name', 100)->nullable();
            $t->string('emergency_phone', 30)->nullable();
        });
        Schema::table('apartments', function (Blueprint $t) {
            $t->string('photo_path')->nullable();
            $t->string('join_code', 20)->nullable()->unique();
            $t->boolean('allow_unit_requests')->default(false);
        });
        Schema::table('apartment_members', function (Blueprint $t) {
            $t->string('invite_status', 10)->default('accepted');
        });
        Schema::table('units', function (Blueprint $t) {
            $t->string('building', 60)->nullable();
        });
        Schema::table('facilities', function (Blueprint $t) {
            $t->string('photo_path')->nullable();
        });
        Schema::create('report_photos', function (Blueprint $t) {
            $t->id();
            $t->foreignId('report_id')->constrained('reports')->cascadeOnDelete();
            $t->string('path');
            $t->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('report_photos');
    }
};

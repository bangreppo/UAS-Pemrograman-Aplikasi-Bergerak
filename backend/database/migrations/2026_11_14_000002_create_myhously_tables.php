<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('apartments', function (Blueprint $t) {
            $t->id();
            $t->foreignId('owner_id')->constrained('users');
            $t->string('name');
            $t->string('address');
            $t->string('city')->nullable();
            $t->string('contact')->nullable();
            $t->text('description')->nullable();
            $t->text('rules')->nullable();
            $t->json('modules')->nullable();
            $t->unsignedBigInteger('service_fee')->default(0);
            $t->unsignedBigInteger('electricity_fee')->default(0);
            $t->unsignedBigInteger('water_fee')->default(0);
            $t->unsignedBigInteger('late_fee_per_day')->default(50000);
            $t->unsignedBigInteger('late_fee_cap')->nullable();
            $t->unsignedTinyInteger('rent_issue_day')->default(24);
            $t->unsignedTinyInteger('due_day')->default(7);
            $t->timestamps();
        });

        Schema::create('apartment_members', function (Blueprint $t) {
            $t->id();
            $t->foreignId('apartment_id')->constrained()->cascadeOnDelete();
            $t->foreignId('user_id')->constrained()->cascadeOnDelete();
            $t->string('role', 10);
            $t->boolean('is_active')->default(true);
            $t->timestamps();
            $t->unique(['apartment_id', 'user_id']);
        });

        Schema::create('unit_types', function (Blueprint $t) {
            $t->id();
            $t->foreignId('apartment_id')->constrained()->cascadeOnDelete();
            $t->string('name');
            $t->decimal('area', 6, 1)->nullable();
            $t->unsignedTinyInteger('bedrooms')->default(0);
            $t->unsignedTinyInteger('bathrooms')->default(1);
            $t->unsignedTinyInteger('capacity')->default(2);
            $t->unsignedBigInteger('rent_price')->default(0);
            $t->json('features')->nullable();
            $t->timestamps();
        });

        Schema::create('units', function (Blueprint $t) {
            $t->id();
            $t->foreignId('apartment_id')->constrained()->cascadeOnDelete();
            $t->foreignId('unit_type_id')->constrained('unit_types');
            $t->string('number', 20);
            $t->integer('floor')->default(1);
            $t->string('status', 20)->default('available');
            $t->timestamps();
            $t->unique(['apartment_id', 'number']);
        });

        Schema::create('occupancies', function (Blueprint $t) {
            $t->id();
            $t->foreignId('apartment_id')->constrained()->cascadeOnDelete();
            $t->foreignId('unit_id')->constrained('units');
            $t->foreignId('user_id')->constrained('users');
            $t->boolean('is_primary')->default(true);
            $t->date('start_date')->nullable();
            $t->date('end_date')->nullable();
            $t->unsignedBigInteger('deposit')->default(0);
            $t->string('status', 10)->default('active');
            $t->timestamp('ended_at')->nullable();
            $t->timestamps();
        });

        Schema::create('invites', function (Blueprint $t) {
            $t->id();
            $t->foreignId('apartment_id')->constrained()->cascadeOnDelete();
            $t->foreignId('unit_id')->constrained('units');
            $t->string('code', 30)->unique();
            $t->boolean('is_primary')->default(true);
            $t->date('start_date')->nullable();
            $t->date('end_date')->nullable();
            $t->unsignedBigInteger('deposit')->default(0);
            $t->timestamp('expires_at')->nullable();
            $t->timestamp('used_at')->nullable();
            $t->foreignId('created_by')->constrained('users');
            $t->timestamps();
        });

        Schema::create('join_requests', function (Blueprint $t) {
            $t->id();
            $t->foreignId('apartment_id')->constrained()->cascadeOnDelete();
            $t->foreignId('unit_id')->constrained('units');
            $t->foreignId('user_id')->constrained('users');
            $t->foreignId('invite_id')->nullable()->constrained('invites');
            $t->boolean('is_primary')->default(true);
            $t->date('start_date')->nullable();
            $t->date('end_date')->nullable();
            $t->unsignedBigInteger('deposit')->default(0);
            $t->string('status', 12)->default('pending');
            $t->string('reject_reason')->nullable();
            $t->timestamps();
        });

        Schema::create('move_out_requests', function (Blueprint $t) {
            $t->id();
            $t->foreignId('apartment_id')->constrained()->cascadeOnDelete();
            $t->foreignId('occupancy_id')->constrained('occupancies');
            $t->foreignId('user_id')->constrained('users');
            $t->date('desired_date');
            $t->text('reason')->nullable();
            $t->string('status', 12)->default('pending');
            $t->string('note')->nullable();
            $t->timestamps();
        });

        Schema::create('services', function (Blueprint $t) {
            $t->id();
            $t->foreignId('apartment_id')->constrained()->cascadeOnDelete();
            $t->string('name');
            $t->unsignedBigInteger('price')->default(0);
            $t->text('description')->nullable();
            $t->boolean('is_active')->default(true);
            $t->timestamps();
        });

        Schema::create('service_subscriptions', function (Blueprint $t) {
            $t->id();
            $t->foreignId('service_id')->constrained('services')->cascadeOnDelete();
            $t->foreignId('occupancy_id')->constrained('occupancies')->cascadeOnDelete();
            $t->timestamps();
            $t->unique(['service_id', 'occupancy_id']);
        });

        Schema::create('bills', function (Blueprint $t) {
            $t->id();
            $t->foreignId('apartment_id')->constrained()->cascadeOnDelete();
            $t->foreignId('unit_id')->constrained('units');
            $t->foreignId('occupancy_id')->constrained('occupancies');
            $t->foreignId('user_id')->constrained('users');
            $t->string('kind', 10);
            $t->string('label');
            $t->date('period');
            $t->date('issued_on');
            $t->date('payable_from');
            $t->date('due_date');
            $t->unsignedBigInteger('total')->default(0);
            $t->string('status', 10)->default('unpaid');
            $t->timestamp('paid_at')->nullable();
            $t->timestamps();
        });

        Schema::create('bill_items', function (Blueprint $t) {
            $t->id();
            $t->foreignId('bill_id')->constrained('bills')->cascadeOnDelete();
            $t->string('type', 20);
            $t->string('label');
            $t->unsignedBigInteger('amount')->default(0);
            $t->timestamps();
        });

        Schema::create('fines', function (Blueprint $t) {
            $t->id();
            $t->foreignId('apartment_id')->constrained()->cascadeOnDelete();
            $t->foreignId('unit_id')->constrained('units');
            $t->foreignId('occupancy_id')->constrained('occupancies');
            $t->foreignId('user_id')->constrained('users');
            $t->unsignedInteger('days')->default(0);
            $t->unsignedBigInteger('amount')->default(0);
            $t->date('started_on');
            $t->string('status', 10)->default('running');
            $t->boolean('is_adjusted')->default(false);
            $t->string('waive_reason')->nullable();
            $t->timestamp('paid_at')->nullable();
            $t->timestamps();
        });

        Schema::create('payments', function (Blueprint $t) {
            $t->id();
            $t->foreignId('apartment_id')->constrained()->cascadeOnDelete();
            $t->foreignId('user_id')->constrained('users');
            $t->foreignId('unit_id')->nullable()->constrained('units');
            $t->string('method', 30);
            $t->unsignedBigInteger('amount')->default(0);
            $t->string('receipt_no', 40)->nullable();
            $t->timestamp('paid_at');
            $t->timestamps();
        });

        Schema::create('payment_items', function (Blueprint $t) {
            $t->id();
            $t->foreignId('payment_id')->constrained('payments')->cascadeOnDelete();
            $t->string('payable_type', 10);
            $t->unsignedBigInteger('payable_id');
            $t->unsignedBigInteger('amount')->default(0);
            $t->timestamps();
        });

        Schema::create('facilities', function (Blueprint $t) {
            $t->id();
            $t->foreignId('apartment_id')->constrained()->cascadeOnDelete();
            $t->string('name');
            $t->text('description')->nullable();
            $t->string('location')->nullable();
            $t->string('hours')->nullable();
            $t->text('rules')->nullable();
            $t->string('status', 20)->default('available');
            $t->timestamps();
        });

        Schema::create('announcements', function (Blueprint $t) {
            $t->id();
            $t->foreignId('apartment_id')->constrained()->cascadeOnDelete();
            $t->foreignId('user_id')->constrained('users');
            $t->string('title');
            $t->text('body');
            $t->string('category', 20)->default('info');
            $t->boolean('is_pinned')->default(false);
            $t->timestamps();
        });

        Schema::create('reports', function (Blueprint $t) {
            $t->id();
            $t->foreignId('apartment_id')->constrained()->cascadeOnDelete();
            $t->foreignId('user_id')->constrained('users');
            $t->foreignId('unit_id')->nullable()->constrained('units');
            $t->foreignId('facility_id')->nullable()->constrained('facilities');
            $t->string('title');
            $t->text('description');
            $t->string('status', 12)->default('menunggu');
            $t->string('reject_reason')->nullable();
            $t->timestamps();
        });

        Schema::create('report_updates', function (Blueprint $t) {
            $t->id();
            $t->foreignId('report_id')->constrained('reports')->cascadeOnDelete();
            $t->foreignId('user_id')->constrained('users');
            $t->string('status', 12);
            $t->text('note')->nullable();
            $t->timestamps();
        });

        Schema::create('app_notifications', function (Blueprint $t) {
            $t->id();
            $t->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $t->unsignedBigInteger('apartment_id')->nullable();
            $t->string('title');
            $t->text('body')->nullable();
            $t->string('type', 20)->default('info');
            $t->timestamp('read_at')->nullable();
            $t->timestamps();
        });
    }

    public function down(): void
    {
        foreach (['app_notifications', 'report_updates', 'reports', 'announcements', 'facilities', 'payment_items', 'payments', 'fines', 'bill_items', 'bills', 'service_subscriptions', 'services', 'move_out_requests', 'join_requests', 'invites', 'occupancies', 'units', 'unit_types', 'apartment_members', 'apartments'] as $table) {
            Schema::dropIfExists($table);
        }
    }
};

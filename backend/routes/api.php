<?php

use App\Http\Controllers\ApartmentController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\BillingController;
use App\Http\Controllers\CommunityController;
use App\Http\Controllers\DemoController;
use App\Http\Controllers\ExportController;
use App\Http\Controllers\MediaController;
use App\Http\Controllers\TenancyController;
use App\Http\Controllers\UnitController;
use Illuminate\Support\Facades\Route;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

Route::get('/media/{dir}/{file}', [MediaController::class, 'show'])->where('file', '[A-Za-z0-9._-]+');
Route::get('/files/receipt/{aid}/{id}', [ExportController::class, 'receipt'])->name('files.receipt')->middleware('signed');
Route::get('/files/export/{aid}/{type}', [ExportController::class, 'export'])->name('files.export')->middleware('signed');

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/me', [AuthController::class, 'me']);
    Route::put('/me', [AuthController::class, 'update']);
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::post('/me/photo', [AuthController::class, 'photo']);
    Route::delete('/me/photo', [AuthController::class, 'removePhoto']);
    Route::post('/admin-invites/{id}/answer', [ApartmentController::class, 'answerInvite']);
    Route::get('/demo', [DemoController::class, 'show']);
    Route::post('/demo/shift', [DemoController::class, 'shift']);
    Route::get('/notifications/unread', [CommunityController::class, 'unread']);

    Route::get('/join/preview', [TenancyController::class, 'preview']);
    Route::post('/join', [TenancyController::class, 'join']);
    Route::post('/join-requests/{id}/cancel', [TenancyController::class, 'cancel']);

    Route::get('/notifications', [CommunityController::class, 'notifications']);
    Route::post('/notifications/read-all', [CommunityController::class, 'readAll']);
    Route::post('/notifications/{id}/read', [CommunityController::class, 'readOne']);

    Route::get('/apartments', [ApartmentController::class, 'index']);
    Route::post('/apartments', [ApartmentController::class, 'store']);

    Route::prefix('/apartments/{aid}')->group(function () {
        Route::get('', [ApartmentController::class, 'show']);
        Route::put('', [ApartmentController::class, 'update']);
        Route::post('/photo', [ApartmentController::class, 'photo']);
        Route::post('/join-code', [ApartmentController::class, 'joinCode']);
        Route::post('/occupancies', [TenancyController::class, 'placeTenant']);
        Route::post('/facilities/{id}/photo', [CommunityController::class, 'facilityPhoto']);
        Route::get('/payments/{id}/pdf-link', [ExportController::class, 'receiptLink']);
        Route::get('/exports/link', [ExportController::class, 'exportLink']);
        Route::get('/dashboard', [ApartmentController::class, 'dashboard']);
        Route::get('/admins', [ApartmentController::class, 'admins']);
        Route::post('/admins', [ApartmentController::class, 'addAdmin']);
        Route::delete('/admins/{id}', [ApartmentController::class, 'removeAdmin']);
        Route::post('/run-billing', [ApartmentController::class, 'runBilling']);

        Route::get('/unit-types', [UnitController::class, 'types']);
        Route::post('/unit-types', [UnitController::class, 'storeType']);
        Route::put('/unit-types/{id}', [UnitController::class, 'updateType']);
        Route::delete('/unit-types/{id}', [UnitController::class, 'destroyType']);
        Route::get('/units', [UnitController::class, 'units']);
        Route::post('/units', [UnitController::class, 'storeUnit']);
        Route::put('/units/{id}', [UnitController::class, 'updateUnit']);
        Route::delete('/units/{id}', [UnitController::class, 'destroyUnit']);

        Route::get('/invites', [TenancyController::class, 'invites']);
        Route::post('/invites', [TenancyController::class, 'storeInvite']);
        Route::get('/join-requests', [TenancyController::class, 'requests']);
        Route::post('/join-requests/{id}/decide', [TenancyController::class, 'decide']);
        Route::get('/occupancies', [TenancyController::class, 'occupancies']);
        Route::put('/occupancies/{id}', [TenancyController::class, 'updateOccupancy']);
        Route::post('/occupancies/{id}/end', [TenancyController::class, 'endOccupancy']);
        Route::get('/move-out', [TenancyController::class, 'moveOuts']);
        Route::post('/move-out', [TenancyController::class, 'storeMoveOut']);
        Route::post('/move-out/{id}/decide', [TenancyController::class, 'decideMoveOut']);

        Route::get('/services', [BillingController::class, 'services']);
        Route::post('/services', [BillingController::class, 'storeService']);
        Route::put('/services/{id}', [BillingController::class, 'updateService']);
        Route::delete('/services/{id}', [BillingController::class, 'destroyService']);
        Route::post('/services/{id}/subscribe', [BillingController::class, 'subscribe']);
        Route::delete('/services/{id}/subscribe/{oid}', [BillingController::class, 'unsubscribe']);

        Route::get('/bills', [BillingController::class, 'bills']);
        Route::post('/bills', [BillingController::class, 'storeBill']);
        Route::get('/fines', [BillingController::class, 'fines']);
        Route::post('/fines/{id}/adjust', [BillingController::class, 'adjustFine']);
        Route::get('/payments', [BillingController::class, 'payments']);
        Route::post('/payments', [BillingController::class, 'pay']);
        Route::get('/payments/{id}', [BillingController::class, 'payment']);

        Route::get('/announcements', [CommunityController::class, 'announcements']);
        Route::post('/announcements', [CommunityController::class, 'storeAnnouncement']);
        Route::put('/announcements/{id}', [CommunityController::class, 'updateAnnouncement']);
        Route::delete('/announcements/{id}', [CommunityController::class, 'destroyAnnouncement']);
        Route::get('/facilities', [CommunityController::class, 'facilities']);
        Route::post('/facilities', [CommunityController::class, 'storeFacility']);
        Route::put('/facilities/{id}', [CommunityController::class, 'updateFacility']);
        Route::delete('/facilities/{id}', [CommunityController::class, 'destroyFacility']);
        Route::get('/reports', [CommunityController::class, 'reports']);
        Route::post('/reports', [CommunityController::class, 'storeReport']);
        Route::get('/reports/{id}', [CommunityController::class, 'report']);
        Route::post('/reports/{id}/status', [CommunityController::class, 'reportStatus']);
    });
});

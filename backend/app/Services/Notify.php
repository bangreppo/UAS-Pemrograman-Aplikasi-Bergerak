<?php

namespace App\Services;

use App\Models\AppNotification;

class Notify
{
    public static function to(array $userIds, ?int $apartmentId, string $title, string $body = '', string $type = 'info'): void
    {
        foreach (array_unique($userIds) as $uid) {
            AppNotification::create([
                'user_id' => $uid,
                'apartment_id' => $apartmentId,
                'title' => $title,
                'body' => $body,
                'type' => $type,
            ]);
        }
    }
}

<?php

use Illuminate\Support\Facades\Schedule;

Schedule::command('myhously:generate-bills')->dailyAt('00:10');
Schedule::command('myhously:calc-fines')->dailyAt('00:20');

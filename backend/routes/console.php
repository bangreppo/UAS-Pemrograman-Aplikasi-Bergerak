<?php

use Illuminate\Support\Facades\Schedule;

Schedule::command('myhously:daily')->dailyAt('00:10');

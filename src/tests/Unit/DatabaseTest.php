<?php

namespace Tests\Unit;

use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseTransactions;
use Tests\TestCase;

class DatabaseTest extends TestCase
{
    use DatabaseTransactions;

    /**
     * @test
     */
    public function DBのテスト()
    {
        User::create(
            $data = [
                'name' => 'テストユーザー',
                'email' => 'test@example.com',
                'password' => bcrypt('password'),
            ],
        );

        $this->assertDatabaseHas('users', $data);
    }
}

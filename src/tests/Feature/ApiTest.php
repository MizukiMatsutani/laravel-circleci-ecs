<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\DatabaseTransactions;
use Illuminate\Foundation\Testing\WithFaker;
use Tests\TestCase;

class ApiTest extends TestCase
{
    use DatabaseTransactions;

    /**
     * @test
     */
    public function APIをテストする()
    {
        $response = $this->json('get', '/api/test?param=bbb');

        $response->assertStatus(200)->assertJson([
            'aaa' => 'bbb',
        ]);
    }
}

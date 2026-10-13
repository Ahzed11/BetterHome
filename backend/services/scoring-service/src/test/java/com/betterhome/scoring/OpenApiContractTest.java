package com.betterhome.scoring;

import static io.restassured.RestAssured.given;

import com.betterhome.common.openapi.OpenApiContract;
import io.quarkus.test.junit.QuarkusTest;
import java.io.IOException;
import org.junit.jupiter.api.Test;

@QuarkusTest
class OpenApiContractTest {

    @Test
    void committedContractMatchesTheApiTheServiceServes() throws IOException {
        String generated =
                given().when().get("/q/openapi").then().statusCode(200).extract().asString();

        OpenApiContract.assertMatchesCommitted("scoring", generated);
    }
}

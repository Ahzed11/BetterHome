package com.betterhome.notifications;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.Matchers.notNullValue;

import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.security.TestSecurity;
import org.junit.jupiter.api.Test;

@QuarkusTest
class ServiceInfoResourceTest {

    @Test
    void metaRequiresAuthentication() {
        given().when().get("/v1/meta").then().statusCode(401);
    }

    @Test
    @TestSecurity(user = "11111111-1111-1111-1111-111111111111", roles = "member")
    void metaReturnsServiceIdentityWhenAuthenticated() {
        given().when()
                .get("/v1/meta")
                .then()
                .statusCode(200)
                .body("service", is("notifications-service"))
                .body("now", notNullValue())
                .body("authSubject", is("11111111-1111-1111-1111-111111111111"));
    }
}

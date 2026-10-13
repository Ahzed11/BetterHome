package com.betterhome.notifications;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;

import com.betterhome.common.oidc.RealOidcTestResource;
import io.quarkus.test.common.QuarkusTestResource;
import io.quarkus.test.junit.QuarkusTest;
import java.util.UUID;
import org.junit.jupiter.api.Test;

@QuarkusTest
@QuarkusTestResource(value = RealOidcTestResource.class, restrictToAnnotatedClass = true)
class RealTokenAuthTest {

    @Test
    void theAuthSubjectIsTheKeycloakSubNotThePreferredUsername() {
        UUID subject = UUID.randomUUID();

        given().auth()
                .oauth2(RealOidcTestResource.token(subject, "demo"))
                .when()
                .get("/v1/meta")
                .then()
                .statusCode(200)
                .body("authSubject", is(subject.toString()));
    }
}

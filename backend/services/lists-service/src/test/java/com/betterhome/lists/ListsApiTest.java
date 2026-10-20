package com.betterhome.lists;

import static com.betterhome.lists.TestWorld.ADMIN_SUBJECT;
import static com.betterhome.lists.TestWorld.ADMIN_USER;
import static com.betterhome.lists.TestWorld.HOUSEHOLD;
import static com.betterhome.lists.TestWorld.MEMBER_SUBJECT;
import static com.betterhome.lists.TestWorld.MEMBER_USER;
import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.is;
import static org.hamcrest.CoreMatchers.nullValue;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.notNullValue;

import com.betterhome.common.openapi.ContractValidation;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.security.TestSecurity;
import io.restassured.http.ContentType;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class ListsApiTest {

    private static final String LISTS = "/v1/households/" + HOUSEHOLD + "/lists";

    @Inject TestWorld world;
    @Inject FixedClock clock;
    @Inject com.betterhome.lists.membership.InMemoryMembershipGateway gateway;

    @BeforeEach
    void seed() {
        world.reset();
        clock.set(Instant.parse("2026-03-01T10:00:00Z"));
    }

    private String createList(String title) {
        return given().filter(ContractValidation.validRequests("lists"))
                .contentType(ContentType.JSON)
                .body(Map.of("title", title))
                .post(LISTS)
                .then()
                .statusCode(201)
                .extract()
                .path("id");
    }

    private String addItem(String listId, String title) {
        return given().filter(ContractValidation.validRequests("lists"))
                .contentType(ContentType.JSON)
                .body(Map.of("title", title))
                .post(LISTS + "/" + listId + "/items")
                .then()
                .statusCode(201)
                .extract()
                .path("id");
    }

    @Test
    @TestSecurity(user = ADMIN_SUBJECT)
    void listLifecycleOverHttp() {
        given().contentType(ContentType.JSON)
                .body(Map.of("title", " Groceries "))
                .post(LISTS)
                .then()
                .statusCode(201)
                .body("title", is("Groceries"))
                .body("householdId", is(HOUSEHOLD.toString()))
                .body("createdBy", is(ADMIN_USER.toString()))
                .body("archivedAt", nullValue());
        String id =
                given().get(LISTS)
                        .then()
                        .statusCode(200)
                        .body("$", hasSize(1))
                        .extract()
                        .path("[0].id");

        given().contentType(ContentType.JSON)
                .body(Map.of("title", "Weekend"))
                .patch(LISTS + "/" + id)
                .then()
                .statusCode(200)
                .body("title", is("Weekend"));
        given().post(LISTS + "/" + id + "/archive")
                .then()
                .statusCode(200)
                .body("archivedAt", notNullValue());

        given().get(LISTS).then().statusCode(200).body("$", hasSize(0));
        given().queryParam("includeArchived", true)
                .get(LISTS)
                .then()
                .statusCode(200)
                .body("$", hasSize(1));
    }

    @Test
    @TestSecurity(user = ADMIN_SUBJECT)
    void archivedListsAnswerConflictToRenameArchiveAndItemChanges() {
        String listId = createList("Old");
        String itemId = addItem(listId, "Milk");
        given().post(LISTS + "/" + listId + "/archive").then().statusCode(200);

        given().post(LISTS + "/" + listId + "/archive")
                .then()
                .statusCode(409)
                .body("code", is("conflict"));
        given().contentType(ContentType.JSON)
                .body(Map.of("title", "x"))
                .patch(LISTS + "/" + listId)
                .then()
                .statusCode(409);
        given().contentType(ContentType.JSON)
                .body(Map.of("title", "x"))
                .post(LISTS + "/" + listId + "/items")
                .then()
                .statusCode(409);
        given().post(LISTS + "/" + listId + "/items/" + itemId + "/check").then().statusCode(409);
        given().delete(LISTS + "/" + listId + "/items/" + itemId).then().statusCode(409);
        given().post(LISTS + "/" + listId + "/reset").then().statusCode(409);
        given().get(LISTS + "/" + listId + "/items").then().statusCode(200).body("$", hasSize(1));
    }

    @Test
    @TestSecurity(user = ADMIN_SUBJECT)
    void blankOrMissingTitlesAreBadRequests() {
        String listId = createList("Groceries");

        given().contentType(ContentType.JSON)
                .body(Map.of("title", " "))
                .post(LISTS)
                .then()
                .statusCode(400);
        given().contentType(ContentType.JSON).body("{}").post(LISTS).then().statusCode(400);
        given().contentType(ContentType.JSON)
                .body(Map.of("title", ""))
                .post(LISTS + "/" + listId + "/items")
                .then()
                .statusCode(400);
    }

    @Test
    @TestSecurity(user = ADMIN_SUBJECT)
    void unknownListsAndItemsAreNotFound() {
        String listId = createList("Groceries");
        String missing = "00000000-0000-0000-0000-000000000000";

        given().get(LISTS + "/" + missing + "/items")
                .then()
                .statusCode(404)
                .body("code", is("not_found"));
        given().post(LISTS + "/" + missing + "/archive").then().statusCode(404);
        given().post(LISTS + "/" + listId + "/items/" + missing + "/check").then().statusCode(404);
        given().delete(LISTS + "/" + listId + "/items/" + missing).then().statusCode(404);
    }

    @Test
    @TestSecurity(user = ADMIN_SUBJECT)
    void anAdminResetsTheListAndGetsItsItemsBack() {
        String listId = world.seedList(HOUSEHOLD, "Packing", clock.now()).id.toString();
        String socks = addItem(listId, "Socks");
        addItem(listId, "Shoes");
        given().post(LISTS + "/" + listId + "/items/" + socks + "/check").then().statusCode(200);

        given().post(LISTS + "/" + listId + "/reset")
                .then()
                .statusCode(200)
                .body("$", hasSize(2))
                .body("[0].title", is("Socks"))
                .body("[0].completedAt", nullValue())
                .body("[1].title", is("Shoes"));
    }

    @Test
    @TestSecurity(user = MEMBER_SUBJECT)
    void aMemberRunsTheItemJourneyWithSoftDeleteAndIsForbiddenToReset() {
        String listId = world.seedList(HOUSEHOLD, "Packing", clock.now()).id.toString();
        String socks = addItem(listId, "Socks");
        String shoes = addItem(listId, "Shoes");
        clock.set(Instant.parse("2026-03-01T11:00:00Z"));

        given().post(LISTS + "/" + listId + "/items/" + socks + "/check")
                .then()
                .statusCode(200)
                .body("completer", is(MEMBER_USER.toString()))
                .body("completedAt", is("2026-03-01T11:00:00Z"));
        given().post(LISTS + "/" + listId + "/items/" + shoes + "/check").then().statusCode(200);
        given().post(LISTS + "/" + listId + "/items/" + shoes + "/uncheck")
                .then()
                .statusCode(200)
                .body("completer", nullValue())
                .body("completedAt", nullValue());
        given().contentType(ContentType.JSON)
                .body(Map.of("title", "Wool socks"))
                .patch(LISTS + "/" + listId + "/items/" + socks)
                .then()
                .statusCode(200)
                .body("title", is("Wool socks"));

        given().post(LISTS + "/" + listId + "/reset").then().statusCode(403);
        given().get(LISTS + "/" + listId + "/items")
                .then()
                .statusCode(200)
                .body("[0].completedAt", is("2026-03-01T11:00:00Z"));

        given().delete(LISTS + "/" + listId + "/items/" + socks).then().statusCode(204);
        given().get(LISTS + "/" + listId + "/items")
                .then()
                .statusCode(200)
                .body("$", hasSize(1))
                .body("[0].id", is(shoes));
        given().delete(LISTS + "/" + listId + "/items/" + socks).then().statusCode(404);
    }

    @Test
    @TestSecurity(user = ADMIN_SUBJECT)
    void anUnreachableHouseholdsServiceIsServiceUnavailableNotForbidden() {
        gateway.setUnavailable(true);

        given().get(LISTS).then().statusCode(503).body("code", is("service_unavailable"));
    }
}

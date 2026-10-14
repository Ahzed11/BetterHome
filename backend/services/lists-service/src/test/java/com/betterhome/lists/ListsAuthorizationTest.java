package com.betterhome.lists;

import static com.betterhome.lists.TestWorld.ADMIN_SUBJECT;
import static com.betterhome.lists.TestWorld.HOUSEHOLD;
import static com.betterhome.lists.TestWorld.LEFT_SUBJECT;
import static com.betterhome.lists.TestWorld.MEMBER_SUBJECT;
import static com.betterhome.lists.TestWorld.OTHER_ADMIN_SUBJECT;
import static com.betterhome.lists.TestWorld.OTHER_HOUSEHOLD;
import static io.restassured.RestAssured.given;
import static org.junit.jupiter.api.Assertions.assertEquals;

import com.betterhome.lists.domain.Checklist;
import com.betterhome.lists.domain.ChecklistItem;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.security.TestSecurity;
import io.restassured.http.ContentType;
import io.restassured.response.Response;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.function.Supplier;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Every endpoint against every kind of caller: admin, member, member who left, member of another
 * household, and nobody.
 */
@QuarkusTest
class ListsAuthorizationTest {

    private static final Instant T0 = Instant.parse("2026-03-01T10:00:00Z");

    @Inject TestWorld world;

    private Checklist list;
    private ChecklistItem item;

    /** One endpoint: how to call it, who may, and what success looks like. */
    private record Endpoint(
            String name,
            String method,
            Supplier<String> path,
            Object body,
            boolean adminOnly,
            int successStatus) {}

    @BeforeEach
    void seed() {
        world.reset();
        list = world.seedList(HOUSEHOLD, "Groceries", T0);
        item = world.seedItem(list.id, "Milk", 0, T0);
    }

    private String lists() {
        return "/v1/households/" + HOUSEHOLD + "/lists";
    }

    private List<Endpoint> endpoints() {
        Map<String, String> title = Map.of("title", "New title");
        return List.of(
                new Endpoint("listLists", "GET", this::lists, null, false, 200),
                new Endpoint("createList", "POST", this::lists, title, true, 201),
                new Endpoint(
                        "renameList", "PATCH", () -> lists() + "/" + list.id, title, true, 200),
                new Endpoint(
                        "archiveList",
                        "POST",
                        () -> lists() + "/" + list.id + "/archive",
                        null,
                        true,
                        200),
                new Endpoint(
                        "listItems",
                        "GET",
                        () -> lists() + "/" + list.id + "/items",
                        null,
                        false,
                        200),
                new Endpoint(
                        "addItem",
                        "POST",
                        () -> lists() + "/" + list.id + "/items",
                        title,
                        false,
                        201),
                new Endpoint(
                        "renameItem",
                        "PATCH",
                        () -> lists() + "/" + list.id + "/items/" + item.id,
                        title,
                        false,
                        200),
                new Endpoint(
                        "checkItem",
                        "POST",
                        () -> lists() + "/" + list.id + "/items/" + item.id + "/check",
                        null,
                        false,
                        200),
                new Endpoint(
                        "uncheckItem",
                        "POST",
                        () -> lists() + "/" + list.id + "/items/" + item.id + "/uncheck",
                        null,
                        false,
                        200),
                new Endpoint(
                        "deleteItem",
                        "DELETE",
                        () -> lists() + "/" + list.id + "/items/" + item.id,
                        null,
                        false,
                        204),
                new Endpoint(
                        "resetList",
                        "POST",
                        () -> lists() + "/" + list.id + "/reset",
                        null,
                        false,
                        200));
    }

    private Response call(Endpoint endpoint) {
        var request = given().contentType(ContentType.JSON);
        if (endpoint.body() != null) {
            request = request.body(endpoint.body());
        }
        return request.request(endpoint.method(), endpoint.path().get());
    }

    private void assertEveryEndpointAnswers(int status) {
        for (Endpoint endpoint : endpoints()) {
            seed();
            assertEquals(status, call(endpoint).statusCode(), endpoint.name());
        }
    }

    @Test
    void anonymousCallersAreUnauthorizedEverywhere() {
        assertEveryEndpointAnswers(401);
    }

    @Test
    @TestSecurity(user = ADMIN_SUBJECT)
    void anAdminMayCallEveryEndpoint() {
        for (Endpoint endpoint : endpoints()) {
            seed();
            assertEquals(endpoint.successStatus(), call(endpoint).statusCode(), endpoint.name());
        }
    }

    @Test
    @TestSecurity(user = MEMBER_SUBJECT)
    void aMemberMayCallEverythingExceptTheAdminOnlyEndpoints() {
        for (Endpoint endpoint : endpoints()) {
            seed();
            int expected = endpoint.adminOnly() ? 403 : endpoint.successStatus();
            assertEquals(expected, call(endpoint).statusCode(), endpoint.name());
        }
    }

    @Test
    @TestSecurity(user = LEFT_SUBJECT)
    void aMemberWhoLeftIsForbiddenEverywhere() {
        assertEveryEndpointAnswers(403);
    }

    @Test
    @TestSecurity(user = OTHER_ADMIN_SUBJECT)
    void anAdminOfAnotherHouseholdIsForbiddenEverywhere() {
        assertEveryEndpointAnswers(403);
    }

    @Test
    @TestSecurity(user = "55555555-5555-5555-5555-555555555555")
    void aUserWhoBelongsToNoHouseholdIsForbiddenEverywhere() {
        assertEveryEndpointAnswers(403);
    }

    @Test
    @TestSecurity(user = OTHER_ADMIN_SUBJECT)
    void aForbiddenCallChangesNothing() {
        assertEveryEndpointAnswers(403);

        assertEquals("Groceries", world.reload(list.id).title);
        assertEquals(false, world.reloadItem(item.id).isChecked());
    }

    @Test
    @TestSecurity(user = OTHER_ADMIN_SUBJECT)
    void anAdminReachesOnlyHisOwnHouseholdsLists() {
        String otherLists = "/v1/households/" + OTHER_HOUSEHOLD + "/lists";

        given().when().get(otherLists).then().statusCode(200);
        given().when().get(otherLists + "/" + list.id + "/items").then().statusCode(404);
        given().contentType(ContentType.JSON)
                .body(Map.of("title", "Hijacked"))
                .when()
                .patch(otherLists + "/" + list.id)
                .then()
                .statusCode(404);
        assertEquals("Groceries", world.reload(list.id).title);
    }
}

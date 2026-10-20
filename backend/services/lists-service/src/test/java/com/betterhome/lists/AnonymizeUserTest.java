package com.betterhome.lists;

import static com.betterhome.lists.TestWorld.ADMIN_USER;
import static com.betterhome.lists.TestWorld.HOUSEHOLD;
import static com.betterhome.lists.TestWorld.MEMBER_USER;
import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.is;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import com.betterhome.common.openapi.ContractValidation;
import com.betterhome.lists.domain.Checklist;
import com.betterhome.lists.domain.ChecklistItem;
import com.betterhome.lists.domain.ListException;
import com.betterhome.lists.service.AnonymizationService;
import com.betterhome.lists.service.AnonymizationService.Result;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.security.TestSecurity;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Account deletion in lists-service: the service itself, then the internal endpoint. */
@QuarkusTest
class AnonymizeUserTest {

    private static final Instant T0 = Instant.parse("2026-03-01T10:00:00Z");
    private static final UUID ANONYMOUS = new UUID(0L, 0L);
    private static final UUID LEAVER = UUID.fromString("dddddddd-dddd-dddd-dddd-dddddddddddd");

    @Inject TestWorld world;
    @Inject AnonymizationService service;

    private Checklist leaversList;
    private Checklist adminsList;
    private ChecklistItem checkedByLeaver;
    private ChecklistItem deletedByLeaver;
    private ChecklistItem byLeaver;
    private ChecklistItem byMember;

    @BeforeEach
    void seed() {
        world.reset();
        QuarkusTransaction.requiringNew()
                .run(
                        () -> {
                            leaversList = Checklist.create(HOUSEHOLD, "Mine", LEAVER, T0);
                            leaversList.persist();
                            adminsList = Checklist.create(HOUSEHOLD, "Admin's", ADMIN_USER, T0);
                            adminsList.persist();
                            byLeaver = item(adminsList, "Eggs", 0, LEAVER);
                            byMember = item(adminsList, "Milk", 1, MEMBER_USER);
                            checkedByLeaver = item(adminsList, "Rice", 2, MEMBER_USER);
                            checkedByLeaver.check(LEAVER, T0);
                            deletedByLeaver = item(adminsList, "Tea", 3, MEMBER_USER);
                            deletedByLeaver.softDelete(LEAVER, T0);
                        });
    }

    private static ChecklistItem item(Checklist list, String title, int position, UUID creator) {
        ChecklistItem item = ChecklistItem.create(list.id, title, position, creator, T0);
        item.persist();
        return item;
    }

    @Test
    void everyColumnHoldingTheUserIsReplacedAndNothingElseChanges() {
        Result result = service.anonymize(LEAVER);

        assertEquals(new Result(1, 1, 1, 1), result);
        assertEquals(ANONYMOUS, world.reload(leaversList.id).createdBy);
        assertEquals(ADMIN_USER, world.reload(adminsList.id).createdBy);
        assertEquals(ANONYMOUS, world.reloadItem(byLeaver.id).creator);
        assertEquals(MEMBER_USER, world.reloadItem(byMember.id).creator);
        ChecklistItem checked = world.reloadItem(checkedByLeaver.id);
        assertEquals(ANONYMOUS, checked.completer);
        assertEquals(T0, checked.completedAt);
        assertEquals(MEMBER_USER, checked.creator);
        ChecklistItem deleted = world.reloadItem(deletedByLeaver.id);
        assertEquals(ANONYMOUS, deleted.deletedBy);
        assertEquals(T0, deleted.deletedAt);
        assertNull(world.reloadItem(byMember.id).completer);
    }

    @Test
    void doingItAgainChangesNothing() {
        service.anonymize(LEAVER);

        assertEquals(new Result(0, 0, 0, 0), service.anonymize(LEAVER));
        assertEquals(ANONYMOUS, world.reload(leaversList.id).createdBy);
    }

    @Test
    void aUserWithNoHistoryHereChangesNothing() {
        assertEquals(new Result(0, 0, 0, 0), service.anonymize(UUID.randomUUID()));
        assertEquals(LEAVER, world.reload(leaversList.id).createdBy);
    }

    @Test
    void theAnonymousIdItselfIsRefused() {
        assertThrows(ListException.BadRequest.class, () -> service.anonymize(ANONYMOUS));
    }

    private String url(UUID user) {
        return "/v1/internal/users/" + user + "/anonymize";
    }

    @Test
    @TestSecurity(user = "households-service", roles = "service")
    void theServiceRoleAnonymizesOverHttp() {
        given().filter(ContractValidation.validRequests("lists"))
                .post(url(LEAVER))
                .then()
                .statusCode(200)
                .body("listsCreated", is(1))
                .body("itemsCreated", is(1))
                .body("itemsCompleted", is(1))
                .body("itemsDeleted", is(1));

        assertEquals(ANONYMOUS, world.reload(leaversList.id).createdBy);
    }

    @Test
    @TestSecurity(user = "households-service", roles = "service")
    void repeatingOverHttpAnswersOkWithZeroes() {
        given().post(url(LEAVER)).then().statusCode(200);

        given().filter(ContractValidation.validRequests("lists"))
                .post(url(LEAVER))
                .then()
                .statusCode(200)
                .body("listsCreated", is(0))
                .body("itemsCreated", is(0))
                .body("itemsCompleted", is(0))
                .body("itemsDeleted", is(0));
    }

    @Test
    @TestSecurity(user = "households-service", roles = "service")
    void anUnknownUserOverHttpAnswersOkWithZeroes() {
        given().post(url(UUID.randomUUID()))
                .then()
                .statusCode(200)
                .body("listsCreated", is(0))
                .body("itemsCreated", is(0));
    }

    @Test
    @TestSecurity(user = "households-service", roles = "service")
    void theAnonymousIdOverHttpIsABadRequest() {
        given().post(url(ANONYMOUS)).then().statusCode(400).body("code", is("bad_request"));
    }

    @Test
    @TestSecurity(
            user = "11111111-1111-1111-1111-111111111111",
            roles = {"admin", "member"})
    void aHouseholdAdminIsForbiddenAndNothingChanges() {
        given().post(url(LEAVER)).then().statusCode(403);

        assertEquals(LEAVER, world.reload(leaversList.id).createdBy);
    }

    @Test
    @TestSecurity(user = "22222222-2222-2222-2222-222222222222")
    void aCallerWithNoRoleIsForbidden() {
        given().post(url(LEAVER)).then().statusCode(403);
    }

    @Test
    void anonymousCallersAreUnauthorized() {
        given().post(url(LEAVER)).then().statusCode(401);

        assertEquals(LEAVER, world.reload(leaversList.id).createdBy);
    }
}

package com.betterhome.households;

import com.betterhome.households.erasure.DeletionTargetException;
import com.betterhome.households.erasure.IdentityAdmin;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.inject.Alternative;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * In-memory identity provider for tests: remembers which subjects were deleted and can be made
 * unavailable. Selected in the test configuration.
 */
@Alternative
@ApplicationScoped
public class InMemoryIdentityAdmin implements IdentityAdmin {

    private final List<UUID> deleted = new CopyOnWriteArrayList<>();
    private volatile boolean down;

    @Override
    public void deleteUser(UUID authSubject) {
        if (down) {
            throw new DeletionTargetException("Keycloak is unreachable");
        }
        if (!deleted.contains(authSubject)) {
            deleted.add(authSubject);
        }
    }

    public List<UUID> deleted() {
        return new ArrayList<>(deleted);
    }

    public void setDown(boolean down) {
        this.down = down;
    }

    public void reset() {
        deleted.clear();
        down = false;
    }
}

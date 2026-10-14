package com.betterhome.households;

import com.betterhome.common.openapi.ContractValidation;
import io.quarkus.test.junit.callback.QuarkusTestBeforeEachCallback;
import io.quarkus.test.junit.callback.QuarkusTestMethodContext;

/** Validates every REST-assured answer of this service's tests against its committed contract. */
public class ContractValidationCallback implements QuarkusTestBeforeEachCallback {

    @Override
    public void beforeEach(QuarkusTestMethodContext context) {
        ContractValidation.installFor("households");
    }
}

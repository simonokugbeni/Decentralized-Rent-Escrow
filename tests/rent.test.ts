import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const landlord = accounts.get("wallet_1")!;
const tenant = accounts.get("wallet_2")!;

describe("rent escrow contract", () => {
    it("successfully registers a property", () => {
        const registerCall = simnet.callPublicFn(
            "rent",
            "register-property",
            [Cl.uint(1000), Cl.uint(2000)],
            landlord
        );
        expect(registerCall.result).toBeOk(Cl.bool(true));

        const propertyDetails = simnet.callReadOnlyFn(
            "rent",
            "get-property-details",
            [Cl.principal(landlord)],
            landlord
        );

        expect(propertyDetails.result).toStrictEqual({
            type: 10,
            value: {
                type: 12,
                data: {
                    tenant: { type: 9 },
                    "rent-amount": { type: 1, value: 1000n },
                    deposit: { type: 1, value: 2000n },
                    "is-maintained": { type: 3 }
                }
            }
        });
    });

    it("allows tenant to pay rent", () => {
        // First register property
        simnet.callPublicFn(
            "rent",
            "register-property",
            [Cl.uint(1000), Cl.uint(2000)],
            landlord
        );

        // Assign tenant to property
        const assignTenantCall = simnet.callPublicFn(
            "rent",
            "assign-tenant",
            [Cl.principal(tenant)],
            landlord
        );
        expect(assignTenantCall.result).toBeOk(Cl.bool(true));

        // Now tenant can pay rent
        const payRentCall = simnet.callPublicFn(
            "rent",
            "pay-rent",
            [Cl.principal(landlord)],
            tenant
        );
        expect(payRentCall.result).toBeOk(Cl.bool(true));
    });
});

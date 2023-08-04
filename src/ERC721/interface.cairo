use starknet::ContractAddress;

#[starknet::interface]
trait IERC165<TState> {
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;
}

#[starknet::interface]
trait IERC721<TState> {
    // ======== view ========
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn owner_of(self: @TState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TState, owner: ContractAddress, operator: ContractAddress
    ) -> bool;
    fn get_approved(self: @TState, token_id: u256) -> ContractAddress;

    // ======== storage ========
    fn approve(ref self: TState, token_id: u256, operator: ContractAddress);
    fn set_approve_for_all(ref self: TState, operator: ContractAddress, approved: bool);
    fn transfer_from(ref self: TState, from: ContractAddress, to: ContractAddress, token_id: u256);
    fn mint(ref self: TState, to: ContractAddress, token_id: u256);
}

#[starknet::interface]
trait IERC721Metadata<TState> {
    fn name(self: @TState) -> felt252;
    fn symbol(self: @TState) -> felt252;
    fn token_uri(self: @TState, token_id: u256) -> felt252;
}

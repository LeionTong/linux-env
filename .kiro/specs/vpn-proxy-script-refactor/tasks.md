# VPN Proxy Script Refactor - Implementation Tasks

## Task Breakdown

### Phase 1: Foundation (Estimated: 4-6 hours)

#### Task 1.1: Configuration Module
**Priority**: High  
**Estimated Time**: 1 hour  
**Dependencies**: None

**Subtasks**:
- [ ] Create associative array for static configuration
- [ ] Create associative array for runtime configuration
- [ ] Implement `config_init()` function
- [ ] Implement `config_detect_proxy()` function
- [ ] Implement `config_validate()` function
- [ ] Implement `config_get()` safe accessor
- [ ] Add validation for all config values
- [ ] Test with both danted and sockd

**Acceptance Criteria**:
- All hardcoded values moved to CONFIG array
- Proxy detection works for both types
- Invalid configuration fails gracefully
- All config values validated on init

---

#### Task 1.2: Logging Module
**Priority**: High  
**Estimated Time**: 1 hour  
**Dependencies**: None

**Subtasks**:
- [ ] Define log level constants
- [ ] Implement `log_init()` function
- [ ] Add timestamp to all log functions
- [ ] Implement `log_sanitize()` for sensitive data
- [ ] Add optional file logging support
- [ ] Implement log level filtering
- [ ] Update all existing log calls to use new format
- [ ] Test log output formatting

**Acceptance Criteria**:
- All logs include timestamps
- Sensitive data is sanitized
- Log levels work correctly
- Output format is consistent

---

#### Task 1.3: Validation Module
**Priority**: High  
**Estimated Time**: 1.5 hours  
**Dependencies**: Logging Module

**Subtasks**:
- [ ] Implement `validate_ipv4()` (improve existing)
- [ ] Implement `validate_file_exists()`
- [ ] Implement `validate_file_writable()`
- [ ] Implement `validate_command_exists()`
- [ ] Implement `validate_service_name()`
- [ ] Implement `validate_port()`
- [ ] Implement `validate_auth_code()` (if format known)
- [ ] Implement `validate_dns_server()`
- [ ] Add detailed error messages for each validator
- [ ] Write unit tests for all validators

**Acceptance Criteria**:
- All validators return 0/1 consistently
- Error messages are specific and actionable
- No side effects in validation functions
- Edge cases handled (empty strings, null, etc.)

---

#### Task 1.4: Error Handling Infrastructure
**Priority**: High  
**Estimated Time**: 1.5 hours  
**Dependencies**: Logging Module

**Subtasks**:
- [ ] Implement global error trap handler
- [ ] Implement cleanup trap handler
- [ ] Create error handler function
- [ ] Add operation state tracking
- [ ] Implement basic rollback skeleton
- [ ] Test error handling with simulated failures
- [ ] Ensure cleanup runs on all exit paths
- [ ] Document error handling behavior

**Acceptance Criteria**:
- Traps catch all errors
- Cleanup always runs
- Error messages include line numbers
- State is tracked during operations

---

#### Task 1.5: State Management
**Priority**: Medium  
**Estimated Time**: 1 hour  
**Dependencies**: Logging Module

**Subtasks**:
- [ ] Create SERVICE_STATE associative array
- [ ] Implement `state_capture()` function
- [ ] Implement `state_restore()` function
- [ ] Implement `state_validate()` function
- [ ] Implement `state_compare()` function
- [ ] Add state logging
- [ ] Test state transitions
- [ ] Document state machine

**Acceptance Criteria**:
- State is captured before operations
- State can be restored on failure
- State validation detects inconsistencies
- State changes are logged

---

### Phase 2: Service Abstraction (Estimated: 6-8 hours)

#### Task 2.1: Service Abstraction Layer
**Priority**: High  
**Estimated Time**: 2 hours  
**Dependencies**: Validation Module, Logging Module

**Subtasks**:
- [ ] Implement `service_start()` wrapper
- [ ] Implement `service_stop()` wrapper
- [ ] Implement `service_restart()` wrapper
- [ ] Implement `service_status()` wrapper
- [ ] Implement `service_is_active()` function
- [ ] Implement `service_is_enabled()` function
- [ ] Implement `process_is_running()` (refactor existing)
- [ ] Implement `process_get_pid()` function
- [ ] Implement `process_wait_for()` with timeout
- [ ] Implement `process_wait_stop()` with timeout
- [ ] Add error handling for all systemctl calls
- [ ] Test with mock systemctl

**Acceptance Criteria**:
- All systemctl calls go through abstraction
- Timeouts work correctly
- Error handling is consistent
- Functions can be mocked for testing

---

#### Task 2.2: VPN Service Module
**Priority**: High  
**Estimated Time**: 2 hours  
**Dependencies**: Service Abstraction Layer, State Management

**Subtasks**:
- [ ] Implement `vpn_init()` function
- [ ] Refactor `vpn_start()` to use service layer
- [ ] Refactor `vpn_stop()` to use service layer
- [ ] Implement `vpn_restart()` function
- [ ] Refactor `vpn_status()` to return structured data
- [ ] Refactor `vpn_get_ip()` with better error handling
- [ ] Implement `vpn_is_connected()` function
- [ ] Implement `vpn_update_auth_code()` function
- [ ] Implement `vpn_validate_connection()` function
- [ ] Add state tracking to VPN operations
- [ ] Add rollback support
- [ ] Test all VPN operations

**Acceptance Criteria**:
- VPN operations use service abstraction
- Auth code handling is secure
- IP retrieval is robust
- Connection validation works
- Rollback restores previous state

---

#### Task 2.3: Proxy Service Module
**Priority**: High  
**Estimated Time**: 2 hours  
**Dependencies**: Service Abstraction Layer, Configuration Module

**Subtasks**:
- [ ] Implement `proxy_init()` function
- [ ] Refactor `proxy_start()` to use service layer
- [ ] Refactor `proxy_stop()` to use service layer
- [ ] Implement `proxy_restart()` function
- [ ] Refactor `proxy_status()` to return structured data
- [ ] Implement `proxy_is_running()` function
- [ ] Implement `proxy_update_config()` with validation
- [ ] Implement `proxy_validate_config()` function
- [ ] Implement `proxy_get_type()` function
- [ ] Abstract danted vs sockd differences
- [ ] Add configuration backup/restore
- [ ] Test with both proxy types

**Acceptance Criteria**:
- Proxy operations use service abstraction
- Both danted and sockd work correctly
- Configuration updates are atomic
- Validation prevents invalid configs
- Rollback restores previous config

---

#### Task 2.4: DNS Service Module
**Priority**: Medium  
**Estimated Time**: 1.5 hours  
**Dependencies**: Validation Module, Logging Module

**Subtasks**:
- [ ] Implement `dns_init()` function
- [ ] Refactor `dns_add_server()` (from nameserver_add)
- [ ] Refactor `dns_remove_server()` (from nameserver_del)
- [ ] Implement `dns_has_server()` function
- [ ] Implement `dns_backup_config()` function
- [ ] Implement `dns_restore_config()` function
- [ ] Implement `dns_validate_config()` function
- [ ] Make operations idempotent
- [ ] Add concurrent modification handling
- [ ] Test backup/restore functionality

**Acceptance Criteria**:
- DNS operations are idempotent
- Backup is created before changes
- Restore works correctly
- Concurrent modifications handled
- Invalid DNS servers rejected

---

### Phase 3: Controller Layer (Estimated: 3-4 hours)

#### Task 3.1: Operation Controller
**Priority**: High  
**Estimated Time**: 2 hours  
**Dependencies**: All service modules

**Subtasks**:
- [ ] Implement `operation_start_all()` function
- [ ] Implement `operation_stop_all()` function
- [ ] Implement `operation_restart_vpn()` function
- [ ] Implement `operation_restart_proxy()` function
- [ ] Implement `operation_status_all()` function
- [ ] Implement `operation_rollback()` function
- [ ] Add state validation between steps
- [ ] Add error recovery logic
- [ ] Test complex workflows
- [ ] Test rollback scenarios

**Acceptance Criteria**:
- All operations coordinate services correctly
- Partial failures trigger rollback
- State is validated at each step
- Error messages are actionable
- Rollback restores consistent state

---

#### Task 3.2: Main Controller Refactor
**Priority**: High  
**Estimated Time**: 1.5 hours  
**Dependencies**: Operation Controller

**Subtasks**:
- [ ] Refactor `main()` to use operation controller
- [ ] Improve argument parsing
- [ ] Separate UI logic from business logic
- [ ] Refactor `prompt_for_action()` for clarity
- [ ] Update `show_usage()` if needed
- [ ] Add dry-run mode support (optional)
- [ ] Test all command-line options
- [ ] Verify backward compatibility

**Acceptance Criteria**:
- Main function is simplified
- All existing commands work identically
- Argument parsing is robust
- Help text is accurate
- Exit codes are consistent

---

### Phase 4: Polish (Estimated: 4-5 hours)

#### Task 4.1: Security Improvements
**Priority**: High  
**Estimated Time**: 1.5 hours  
**Dependencies**: VPN Module, Logging Module

**Subtasks**:
- [ ] Implement secure auth code input (no echo)
- [ ] Add auth code sanitization in logs
- [ ] Implement file permission validation
- [ ] Add command injection prevention
- [ ] Validate all file paths
- [ ] Test with malicious inputs
- [ ] Document security considerations
- [ ] Review for additional vulnerabilities

**Acceptance Criteria**:
- Auth codes never appear in logs
- Auth codes not echoed during input
- File permissions validated
- Command injection prevented
- Security review completed

---

#### Task 4.2: Performance Optimizations
**Priority**: Medium  
**Estimated Time**: 1.5 hours  
**Dependencies**: Service Abstraction Layer

**Subtasks**:
- [ ] Replace fixed sleeps with polling
- [ ] Optimize IP parsing (single awk)
- [ ] Implement parallel status checks
- [ ] Profile script execution time
- [ ] Optimize slow operations
- [ ] Test performance improvements
- [ ] Document performance characteristics
- [ ] Ensure no regressions

**Acceptance Criteria**:
- Script startup < 1 second
- Service operations complete within timeout
- IP retrieval < 10 seconds
- Status checks run in parallel
- No performance regressions

---

#### Task 4.3: Documentation
**Priority**: Medium  
**Estimated Time**: 1.5 hours  
**Dependencies**: All previous tasks

**Subtasks**:
- [ ] Add function header comments
- [ ] Document complex logic
- [ ] Add usage examples
- [ ] Create troubleshooting guide
- [ ] Document error messages
- [ ] Add inline comments for clarity
- [ ] Update README if exists
- [ ] Create migration guide if needed

**Acceptance Criteria**:
- All functions have header comments
- Complex logic is explained
- Examples are provided
- Troubleshooting guide is comprehensive
- Documentation is accurate

---

#### Task 4.4: Testing
**Priority**: High  
**Estimated Time**: 2 hours  
**Dependencies**: All previous tasks

**Subtasks**:
- [ ] Set up bats testing framework
- [ ] Write unit tests for validators
- [ ] Write unit tests for utilities
- [ ] Write integration tests for operations
- [ ] Write tests for error scenarios
- [ ] Write tests for rollback
- [ ] Achieve >80% coverage
- [ ] Run shellcheck and fix issues
- [ ] Test on clean system
- [ ] Test with both proxy types

**Acceptance Criteria**:
- Test coverage >80%
- All tests pass
- No shellcheck warnings
- Works on clean system
- Both proxy types tested

---

### Phase 5: Validation (Estimated: 2-3 hours)

#### Task 5.1: Manual Testing
**Priority**: High  
**Estimated Time**: 1.5 hours  
**Dependencies**: All previous tasks

**Subtasks**:
- [ ] Test all command-line options
- [ ] Test with valid auth codes
- [ ] Test with invalid auth codes
- [ ] Test error scenarios
- [ ] Test rollback scenarios
- [ ] Test with danted
- [ ] Test with sockd
- [ ] Test on different systems
- [ ] Verify backward compatibility
- [ ] Test edge cases

**Acceptance Criteria**:
- All commands work as expected
- Error handling works correctly
- Rollback works correctly
- Both proxy types work
- No regressions found

---

#### Task 5.2: Code Review and Cleanup
**Priority**: Medium  
**Estimated Time**: 1 hour  
**Dependencies**: Manual Testing

**Subtasks**:
- [ ] Review all code for consistency
- [ ] Remove dead code
- [ ] Remove debug statements
- [ ] Verify naming conventions
- [ ] Check for code duplication
- [ ] Verify error messages
- [ ] Final shellcheck run
- [ ] Final test run
- [ ] Update version number
- [ ] Tag release

**Acceptance Criteria**:
- Code is consistent
- No dead code remains
- Naming is consistent
- No duplication
- All tests pass
- Ready for release

---

## Risk Assessment

### High Risk Items
1. **Rollback mechanism**: Complex to implement correctly
   - Mitigation: Extensive testing, start with simple cases
   
2. **Backward compatibility**: Breaking existing usage
   - Mitigation: Comprehensive testing, maintain exact CLI interface

3. **State management**: Race conditions or inconsistencies
   - Mitigation: Careful design, atomic operations where possible

### Medium Risk Items
1. **Performance regressions**: New abstractions add overhead
   - Mitigation: Profile before/after, optimize hot paths

2. **Proxy type differences**: Subtle differences between danted/sockd
   - Mitigation: Test both thoroughly, abstract differences

3. **Error handling complexity**: Too many edge cases
   - Mitigation: Start simple, add complexity incrementally

### Low Risk Items
1. **Documentation**: Time-consuming but low risk
   - Mitigation: Document as you go

2. **Testing setup**: Learning curve for bats
   - Mitigation: Start with simple tests, expand gradually

## Dependencies

### External Dependencies
- bash 4.0+
- systemd
- strongswan (ipsec)
- danted or sockd
- Standard Unix utilities (awk, sed, grep, etc.)

### Optional Dependencies
- bats (for testing)
- shellcheck (for linting)

## Timeline Estimate

- **Phase 1**: 4-6 hours (Foundation)
- **Phase 2**: 6-8 hours (Service Abstraction)
- **Phase 3**: 3-4 hours (Controller Layer)
- **Phase 4**: 4-5 hours (Polish)
- **Phase 5**: 2-3 hours (Validation)

**Total**: 19-26 hours

**Recommended Schedule**:
- Week 1: Phases 1-2 (Foundation + Service Abstraction)
- Week 2: Phases 3-4 (Controller + Polish)
- Week 3: Phase 5 (Validation + Cleanup)

## Success Metrics

### Code Quality
- [ ] Cyclomatic complexity reduced by 30%
- [ ] No shellcheck warnings
- [ ] Test coverage >80%
- [ ] All functions <50 lines

### Functionality
- [ ] All existing features work
- [ ] No regressions
- [ ] Improved error messages
- [ ] Rollback works correctly

### Performance
- [ ] Script startup <1s
- [ ] Service operations within timeout
- [ ] No performance regressions

### Maintainability
- [ ] Clear module boundaries
- [ ] Comprehensive documentation
- [ ] Easy to extend
- [ ] Easy to test

## Notes

- Each task should be completed and tested before moving to the next
- Commit after each completed task
- Run full test suite before each commit
- Keep backward compatibility throughout
- Document any deviations from the plan

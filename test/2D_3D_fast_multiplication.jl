using LinearAlgebra, DiffEqOperators, Random, Test, BandedMatrices, SparseArrays

function fourth_deriv_approx_stencil(N)
    A = zeros(N,N+2)
    A[1,1:8] = [3.5 -56/3 42.5 -54.0 251/6 -20.0 5.5 -2/3]
    A[2,1:8] = [2/3 -11/6 0.0 31/6 -22/3 4.5 -4/3 1/6]
    A[N-1,N-5:end] = reverse([2/3 -11/6 0.0 31/6 -22/3 4.5 -4/3 1/6], dims=2)
    A[N,N-5:end] = reverse([3.5 -56/3 42.5 -54.0 251/6 -20.0 5.5 -2/3], dims=2)
    for i in 3:N-2
        A[i,i-2:i+4] = [-1/6 2.0 -13/2 28/3 -13/2 2.0 -1/6]
    end
    return A
end

function second_derivative_stencil(N)
  A = zeros(N,N+2)
  for i in 1:N, j in 1:N+2
      (j-i==0 || j-i==2) && (A[i,j]=1)
      j-i==1 && (A[i,j]=-2)
  end
  A
end

@testset "2D Multiplication with no boundary points and dx = 1.0" begin

    # Test (Lxx + Lyy)*M, dx = 1.0, no coefficient
    N = 100
    M = zeros(N+2,N+2)
    M_temp = zeros(N,N)

    for i in 1:N+2
        for j in 1:N+2
            M[i,j] = cos(0.1i)+sin(0.1j)
        end
    end

    Lxx = CenteredDifference{1}(2,2,1.0,N)
    Lyy = CenteredDifference{2}(2,2,1.0,N)
    A = Lxx + Lyy

    mul!(M_temp, A, M)

    @test M_temp ≈ ((Lxx*M)[1:N,2:N+1] +(Lyy*M)[2:N+1,1:N])

    # Test a single axis, multiple operators: (Lx + Lxx)*M, dx = 1.0
    Lx = CenteredDifference{1}(1,2,1.0,N)
    A = Lx + Lxx

    M_temp = zeros(100,102)
    mul!(M_temp, A, M)

    @test M_temp ≈ ((Lx*M)+(Lxx*M))

    # Test a single axis, multiple operators: (Ly + Lyy)*M, dx = 1.0, no coefficient
    Ly = CenteredDifference{2}(1,2,1.0,N)
    A = Ly + Lyy

    M_temp = zeros(102,100)
    mul!(M_temp, A, M)

    @test M_temp ≈ ((Ly*M)+(Lyy*M))

    # Test multiple operators on both axis: (Lx + Ly + Lxx + Lyy)*M, no coefficient
    A = Lx + Ly + Lxx + Lyy
    M_temp = zeros(100,100)
    mul!(M_temp, A, M)

    @test M_temp ≈ ((Lx*M)[1:N,2:N+1] +(Ly*M)[2:N+1,1:N] + (Lxx*M)[1:N,2:N+1] +(Lyy*M)[2:N+1,1:N])
end

@testset "2D Multiplication with identical bpc and dx = 1.0" begin

    # Test (Lxxxx + Lyyyy)*M, dx = 1.0, no coefficient, two boundary points on each axis
    N = 100
    M = zeros(N+2,N+2)
    M_temp = zeros(N,N)

    for i in 1:N+2
        for j in 1:N+2
            M[i,j] = cos(0.1i)+sin(0.1j)
        end
    end

    Lx4 = CenteredDifference{1}(4,4,1.0,N)
    Ly4 = CenteredDifference{2}(4,4,1.0,N)
    A = Lx4 + Ly4

    mul!(M_temp, A, M)

    @test M_temp ≈ ((Lx4*M)[1:N,2:N+1] +(Ly4*M)[2:N+1,1:N])

    # Test a single axis, multiple operators: (Lxxx + Lxxxx)*M, dx = 1.0
    Lx3 = CenteredDifference{1}(3,4,1.0,N)
    A = Lx3 + Lx4

    M_temp = zeros(100,102)
    mul!(M_temp, A, M)

    @test M_temp ≈ ((Lx3*M)+(Lx4*M))

    # Test a single axis, multiple operators: (Lyyy + Lyyyy)*M, dx = 1.0, no coefficient
    Ly3 = CenteredDifference{2}(3,4,1.0,N)
    A = Ly3 + Ly4

    M_temp = zeros(102,100)
    mul!(M_temp, A, M)

    @test M_temp ≈ ((Ly3*M)+(Ly4*M))

    # Test multiple operators on both axis: (Lxxx + Lyyy + Lxxxx + Lyyyy)*M, no coefficient
    A = Lx3 + Ly3 + Lx4 + Ly4
    M_temp = zeros(100,100)
    mul!(M_temp, A, M)

    @test M_temp ≈ ((Lx3*M)[1:N,2:N+1] +(Ly3*M)[2:N+1,1:N] + (Lx4*M)[1:N,2:N+1] +(Ly4*M)[2:N+1,1:N])

    # Test (Lxxx + Lyyy)*M, no coefficient. These operators have non-symmetric interior stencils
    A = Lx3 + Ly3
    M_temp = zeros(100,100)
    mul!(M_temp, A, M)

    @test M_temp ≈ ((Lx3*M)[1:N,2:N+1] +(Ly3*M)[2:N+1,1:N])

end

@testset "2D Multiplication with differing bpc and dx = 1.0" begin

    N = 100
    M = zeros(N+2,N+2)
    M_temp = zeros(N,N+2)
    for i in 1:N+2
        for j in 1:N+2
            M[i,j] = cos(0.1i)+sin(0.1j)
        end
    end

    # Lx2 has 0 boundary points
    Lx2 = CenteredDifference{1}(2,2,1.0,N)
    # Lx3 has 1 boundary point
    Lx3 = CenteredDifference{1}(3,3,1.0,N)
    # Lx4 has 2 boundary points
    Lx4 = CenteredDifference{1}(4,4,1.0,N)

    # Test a single axis, multiple operators: (Lxx+Lxxxx)*M, dx = 1.0
    A = Lx2+Lx4
    mul!(M_temp, A, M)
    @test M_temp ≈ ((Lx2*M) + (Lx4*M))

    # Test a single axis, multiple operators: (Lxx++Lxxx+Lxxxx)*M, dx = 1.0
    A += Lx3
    mul!(M_temp, A, M)
    @test M_temp ≈ ((Lx2*M) + (Lx3*M) + (Lx4*M))


    # Ly2 has 0 boundary points
    Ly2 = CenteredDifference{2}(2,2,1.0,N)
    # Ly3 has 1 boundary point
    Ly3 = CenteredDifference{2}(3,3,1.0,N)
    # Ly4 has 2 boundary points
    Ly4 = CenteredDifference{2}(4,4,1.0,N)
    M_temp = zeros(N+2,N)

    # Test a single axis, multiple operators: (Lyy+Lyyyy)*M, dx = 1.0
    A = Ly2+Ly4
    mul!(M_temp, A, M)
    @test M_temp ≈ ((Ly2*M) + (Ly4*M))

    # Test a single axis, multiple operators: (Lyy++Lyyy+Lyyyy)*M, dx = 1.0
    A += Ly3
    mul!(M_temp, A, M)
    @test M_temp ≈ ((Ly2*M) + (Ly3*M) + (Ly4*M))


    # Test multiple operators on both axis: (Lxx + Lyy + Lxxx + Lyyy + Lxxxx + Lyyyy)*M, no coefficient
    A = Lx2 + Ly2 + Lx3 + Ly3 + Lx4 + Ly4
    M_temp = zeros(100,100)
    mul!(M_temp, A, M)

    @test M_temp ≈ ((Lx2*M)[1:N,2:N+1]+(Ly2*M)[2:N+1,1:N]+(Lx3*M)[1:N,2:N+1] +(Ly3*M)[2:N+1,1:N] + (Lx4*M)[1:N,2:N+1] +(Ly4*M)[2:N+1,1:N])

end

@testset "2D Multiplication with identical bpc and non-trivial dx = dy = 0.1" begin

    # Test (Lxxxx + Lyyyy)*M, dx = 0.1, dy = 0.01, no coefficient, two boundary points on each axis
    N = 100
    M = zeros(N+2,N+2)
    M_temp = zeros(N,N)

    for i in 1:N+2
        for j in 1:N+2
            M[i,j] = cos(0.1i)+sin(0.1j)
        end
    end

    Lx4 = CenteredDifference{1}(4,4,0.1,N)
    Ly4 = CenteredDifference{2}(4,4,0.1,N)
    A = Lx4 + Ly4

    mul!(M_temp, A, M)

    @test M_temp ≈ ((Lx4*M)[1:N,2:N+1] +(Ly4*M)[2:N+1,1:N])

    # Test a single axis, multiple operators: (Lxxx + Lxxxx)*M, dx = 0.1
    Lx3 = CenteredDifference{1}(3,4,0.1,N)
    A = Lx3 + Lx4

    M_temp = zeros(100,102)
    mul!(M_temp, A, M)

    @test M_temp ≈ ((Lx3*M)+(Lx4*M))

    # Test a single axis, multiple operators: (Lyyy + Lyyyy)*M, dx = 0.01, no coefficient
    Ly3 = CenteredDifference{2}(3,4,0.1,N)
    A = Ly3 + Ly4

    M_temp = zeros(102,100)
    mul!(M_temp, A, M)

    @test M_temp ≈ ((Ly3*M)+(Ly4*M))

    # Test multiple operators on both axis: (Lxxx + Lyyy + Lxxxx + Lyyyy)*M, no coefficient dx =
    A = Lx3 + Ly3 + Lx4 + Ly4
    M_temp = zeros(100,100)
    mul!(M_temp, A, M)

    @test M_temp ≈ ((Lx3*M)[1:N,2:N+1] +(Ly3*M)[2:N+1,1:N] + (Lx4*M)[1:N,2:N+1] +(Ly4*M)[2:N+1,1:N])

    # Test (Lxxx + Lyyy)*M, no coefficient. These operators have non-symmetric interior stencils
    A = Lx3 + Ly3
    M_temp = zeros(100,100)
    mul!(M_temp, A, M)

    @test M_temp ≈ ((Lx3*M)[1:N,2:N+1] +(Ly3*M)[2:N+1,1:N])

end

@testset "2D Multiplication with identical bpc and non-trivial dx = 0.1, dy = 0.25" begin

    # Test (Lxxxx + Lyyyy)*M, dx = 0.1, dy = 0.01, no coefficient, two boundary points on each axis
    dx = 0.1
    dy = 0.25
    N = 100
    M = zeros(N+2,N+2)
    M_temp = zeros(N,N)

    for i in 1:N+2
        for j in 1:N+2
            M[i,j] = cos(dx*i)+sin(dy*j)
        end
    end

    Lx4 = CenteredDifference{1}(4,4,dx,N)
    Ly4 = CenteredDifference{2}(4,4,dy,N)
    A = Lx4 + Ly4

    mul!(M_temp, A, M)

    @test M_temp ≈ ((Lx4*M)[1:N,2:N+1] +(Ly4*M)[2:N+1,1:N])

    # Test a single axis, multiple operators: (Lxxx + Lxxxx)*M, dx = 0.1
    Lx3 = CenteredDifference{1}(3,4,dx,N)
    A = Lx3 + Lx4

    M_temp = zeros(100,102)
    mul!(M_temp, A, M)

    @test M_temp ≈ ((Lx3*M)+(Lx4*M))

    # Test a single axis, multiple operators: (Lyyy + Lyyyy)*M, dx = 0.01, no coefficient
    Ly3 = CenteredDifference{2}(3,4,dy,N)
    A = Ly3 + Ly4

    M_temp = zeros(102,100)
    mul!(M_temp, A, M)

    @test M_temp ≈ ((Ly3*M)+(Ly4*M))

    # Test multiple operators on both axis: (Lxxx + Lyyy + Lxxxx + Lyyyy)*M, no coefficient dx =
    A = Lx3 + Ly3 + Lx4 + Ly4
    M_temp = zeros(100,100)
    mul!(M_temp, A, M)

    @test M_temp ≈ ((Lx3*M)[1:N,2:N+1] +(Ly3*M)[2:N+1,1:N] + (Lx4*M)[1:N,2:N+1] +(Ly4*M)[2:N+1,1:N])

    # Test (Lxxx + Lyyy)*M, no coefficient. These operators have non-symmetric interior stencils
    A = Lx3 + Ly3
    M_temp = zeros(100,100)
    mul!(M_temp, A, M)

    @test M_temp ≈ ((Lx3*M)[1:N,2:N+1] +(Ly3*M)[2:N+1,1:N])

end

@testset "2D Multiplication with differing bpc and non-trivial dx = dy = 0.1" begin

    dx = 0.1
    dy = 0.1
    N = 100
    M = zeros(N+2,N+2)
    M_temp = zeros(N,N+2)
    for i in 1:N+2
        for j in 1:N+2
            M[i,j] = cos(dx*i)+sin(dy*j)
        end
    end

    # Lx2 has 0 boundary points
    Lx2 = CenteredDifference{1}(2,2,dx,N)
    # Lx3 has 1 boundary point
    Lx3 = CenteredDifference{1}(3,3,dx,N)
    # Lx4 has 2 boundary points
    Lx4 = CenteredDifference{1}(4,4,dx,N)

    # Test a single axis, multiple operators: (Lxx+Lxxxx)*M, dx = 1.0
    A = Lx2+Lx4
    mul!(M_temp, A, M)
    @test M_temp ≈ ((Lx2*M) + (Lx4*M))

    # Test a single axis, multiple operators: (Lxx++Lxxx+Lxxxx)*M, dx = 1.0
    A += Lx3
    mul!(M_temp, A, M)
    @test M_temp ≈ ((Lx2*M) + (Lx3*M) + (Lx4*M))


    # Ly2 has 0 boundary points
    Ly2 = CenteredDifference{2}(2,2,dy,N)
    # Ly3 has 1 boundary point
    Ly3 = CenteredDifference{2}(3,3,dy,N)
    # Ly4 has 2 boundary points
    Ly4 = CenteredDifference{2}(4,4,dy,N)
    M_temp = zeros(N+2,N)

    # Test a single axis, multiple operators: (Lyy+Lyyyy)*M, dx = 1.0
    A = Ly2+Ly4
    mul!(M_temp, A, M)
    @test M_temp ≈ ((Ly2*M) + (Ly4*M))

    # Test a single axis, multiple operators: (Lyy++Lyyy+Lyyyy)*M, dx = 1.0
    A += Ly3
    mul!(M_temp, A, M)
    @test M_temp ≈ ((Ly2*M) + (Ly3*M) + (Ly4*M))


    # Test multiple operators on both axis: (Lxx + Lyy + Lxxx + Lyyy + Lxxxx + Lyyyy)*M, no coefficient
    A = Lx2 + Ly2 + Lx3 + Ly3 + Lx4 + Ly4
    M_temp = zeros(100,100)
    mul!(M_temp, A, M)

    @test M_temp ≈ ((Lx2*M)[1:N,2:N+1]+(Ly2*M)[2:N+1,1:N]+(Lx3*M)[1:N,2:N+1] +(Ly3*M)[2:N+1,1:N] + (Lx4*M)[1:N,2:N+1] +(Ly4*M)[2:N+1,1:N])

end

@testset "2D Multiplication with differing bpc and non-trivial dx = 0.1, dy = 0.25" begin

    dx = 0.1
    dy = 0.25
    N = 100
    M = zeros(N+2,N+2)
    M_temp = zeros(N,N+2)
    for i in 1:N+2
        for j in 1:N+2
            M[i,j] = cos(dx*i)+sin(dy*j)
        end
    end

    # Lx2 has 0 boundary points
    Lx2 = CenteredDifference{1}(2,2,dx,N)
    # Lx3 has 1 boundary point
    Lx3 = CenteredDifference{1}(3,3,dx,N)
    # Lx4 has 2 boundary points
    Lx4 = CenteredDifference{1}(4,4,dx,N)

    # Test a single axis, multiple operators: (Lxx+Lxxxx)*M, dx = 1.0
    A = Lx2+Lx4
    mul!(M_temp, A, M)
    @test M_temp ≈ ((Lx2*M) + (Lx4*M))

    # Test a single axis, multiple operators: (Lxx++Lxxx+Lxxxx)*M, dx = 1.0
    A += Lx3
    mul!(M_temp, A, M)
    @test M_temp ≈ ((Lx2*M) + (Lx3*M) + (Lx4*M))


    # Ly2 has 0 boundary points
    Ly2 = CenteredDifference{2}(2,2,dy,N)
    # Ly3 has 1 boundary point
    Ly3 = CenteredDifference{2}(3,3,dy,N)
    # Ly4 has 2 boundary points
    Ly4 = CenteredDifference{2}(4,4,dy,N)
    M_temp = zeros(N+2,N)

    # Test a single axis, multiple operators: (Lyy+Lyyyy)*M, dx = 1.0
    A = Ly2+Ly4
    mul!(M_temp, A, M)
    @test M_temp ≈ ((Ly2*M) + (Ly4*M))

    # Test a single axis, multiple operators: (Lyy++Lyyy+Lyyyy)*M, dx = 1.0
    A += Ly3
    mul!(M_temp, A, M)
    @test M_temp ≈ ((Ly2*M) + (Ly3*M) + (Ly4*M))


    # Test multiple operators on both axis: (Lxx + Lyy + Lxxx + Lyyy + Lxxxx + Lyyyy)*M, no coefficient
    A = Lx2 + Ly2 + Lx3 + Ly3 + Lx4 + Ly4
    M_temp = zeros(100,100)
    mul!(M_temp, A, M)

    @test M_temp ≈ ((Lx2*M)[1:N,2:N+1]+(Ly2*M)[2:N+1,1:N]+(Lx3*M)[1:N,2:N+1] +(Ly3*M)[2:N+1,1:N] + (Lx4*M)[1:N,2:N+1] +(Ly4*M)[2:N+1,1:N])

end
